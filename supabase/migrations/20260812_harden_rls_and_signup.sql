-- Correctifs de revue. Les migrations visées sont déjà appliquées : on corrige
-- ici plutôt que de les réécrire, sinon les bases existantes resteraient en
-- l'état.

-- ==========================================================================
-- 1. `salons` : rétablir l'isolation multi-tenant
-- ==========================================================================
-- 20260809 supprimait les policies nommées « Authenticated users full access
-- to X » mais aucune ne portait ce nom sur `salons` : les trois policies
-- permissives de 20260806 ont survécu. PostgreSQL combine les policies
-- permissives par OU, donc `USING (true)` l'emportait sur
-- `id = get_auth_salon_id()` et « Tenant isolation for salons » ne filtrait
-- plus rien — chaque gérant lisait et supprimait les salons des autres.
DROP POLICY IF EXISTS "Authenticated users can read salons" ON public.salons;
DROP POLICY IF EXISTS "Authenticated users can update salons" ON public.salons;
DROP POLICY IF EXISTS "Authenticated users can delete salons" ON public.salons;

-- Devenue inutile : `create()` passe par `create_salon_for_signup`, plus aucun
-- chemin client n'insère directement. La conserver laissait une écriture
-- anonyme ouverte sans usage.
DROP POLICY IF EXISTS "Anyone can create a salon during signup" ON public.salons;

-- « Tenant isolation for salons » est en FOR ALL sans WITH CHECK : à l'INSERT,
-- PostgreSQL retombe sur l'expression USING, qui exige que la ligne appartienne
-- déjà au salon du créateur — impossible à satisfaire. Sans la policy ci-dessus
-- l'insert direct est donc fermé, ce qui est l'intention : la création passe
-- exclusivement par la RPC SECURITY DEFINER.

-- ==========================================================================
-- 2. `verify_pin` : ne pas appeler crypt() sur un PIN stocké en clair
-- ==========================================================================
-- Rien ne hache les PIN à l'écriture aujourd'hui. Sur un PIN erroné, la
-- première comparaison échouait et `crypt('1234', '5678')` levait
-- « invalid salt », transformant un simple refus en erreur SQL.
CREATE OR REPLACE FUNCTION public.verify_pin(
  p_profile_id UUID,
  p_pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored_pin TEXT;
BEGIN
  SELECT pin_code INTO v_stored_pin
  FROM public.profiles
  WHERE id = p_profile_id;

  IF v_stored_pin IS NULL OR v_stored_pin = '' THEN
    RETURN FALSE;
  END IF;

  -- Un hash pgcrypto commence toujours par '$' ($2a$, $2b$, $6$…). Toute autre
  -- valeur est un PIN en clair hérité : comparaison directe, jamais crypt().
  IF v_stored_pin LIKE '$%' THEN
    RETURN v_stored_pin = crypt(p_pin, v_stored_pin);
  END IF;

  RETURN v_stored_pin = p_pin;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_pin(UUID, TEXT) TO authenticated;

-- ==========================================================================
-- 3. `create_salon_for_signup` : valider les entrées
-- ==========================================================================
-- La fonction est SECURITY DEFINER et exécutable par `anon` : la clé anonyme
-- étant lisible dans l'APK, n'importe qui peut l'appeler. On refuse au moins
-- les lignes vides. Un plafond par IP relève d'une edge function et reste à
-- faire — voir la note en fin de fichier.
CREATE OR REPLACE FUNCTION public.create_salon_for_signup(
  p_name TEXT,
  p_phone TEXT,
  p_address TEXT
)
RETURNS public.salons
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon public.salons;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Le nom du salon est obligatoire'
      USING ERRCODE = 'check_violation';
  END IF;

  IF length(btrim(p_name)) > 120 THEN
    RAISE EXCEPTION 'Nom de salon trop long'
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.salons (name, phone, address)
  VALUES (btrim(p_name), nullif(btrim(coalesce(p_phone, '')), ''),
          nullif(btrim(coalesce(p_address, '')), ''))
  RETURNING * INTO v_salon;

  RETURN v_salon;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_salon_for_signup(TEXT, TEXT, TEXT)
  TO anon, authenticated;

-- ==========================================================================
-- 4. Nettoyage d'un salon resté sans gérant
-- ==========================================================================
-- `registerSalon` crée le salon avant le compte. Si le `signUp` échoue (email
-- refusé, quota d'envoi atteint…), la ligne est déjà committée et l'isolation
-- tenant la rend ensuite invisible depuis l'app. L'appelant est encore anonyme
-- à ce stade, d'où le SECURITY DEFINER — la suppression est bornée aux salons
-- réellement orphelins, donc inoffensive même appelée à tort.
CREATE OR REPLACE FUNCTION public.delete_orphan_salon(p_salon_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.salons s
   WHERE s.id = p_salon_id
     AND NOT EXISTS (
       SELECT 1 FROM public.profiles p WHERE p.salon_id = s.id
     );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_orphan_salon(UUID) TO anon, authenticated;

-- Rattrapage des salons orphelins déjà accumulés.
DELETE FROM public.salons s
 WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.salon_id = s.id);

-- ==========================================================================
-- 5. `handle_new_user` : ne pas réclamer une fiche d'un autre salon
-- ==========================================================================
-- La condition `(v_salon_id IS NULL OR salon_id = v_salon_id)` faisait
-- correspondre, quand l'inscription ne transmet pas de `salon_id`, n'importe
-- quelle fiche non réclamée portant cet email — y compris dans un autre salon.
-- Avec `LIMIT 1` sans `ORDER BY`, le choix était en plus arbitraire.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_salon_id UUID := (NEW.raw_user_meta_data->>'salon_id')::uuid;
  v_claimed  UUID;
  v_matches  INTEGER;
BEGIN
  -- Sans salon cible, on ne réclame que s'il n'existe aucune ambiguïté.
  SELECT count(*) INTO v_matches
    FROM public.profiles
   WHERE user_id IS NULL
     AND email IS NOT NULL
     AND lower(email) = lower(NEW.email)
     AND (v_salon_id IS NULL OR salon_id = v_salon_id);

  IF v_matches = 1 THEN
    SELECT id INTO v_claimed
      FROM public.profiles
     WHERE user_id IS NULL
       AND email IS NOT NULL
       AND lower(email) = lower(NEW.email)
       AND (v_salon_id IS NULL OR salon_id = v_salon_id);
  END IF;

  IF v_claimed IS NOT NULL THEN
    UPDATE public.profiles
       SET user_id   = NEW.id,
           full_name = COALESCE(
             NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
             full_name
           )
     WHERE id = v_claimed;
  ELSE
    -- Plusieurs fiches candidates (même email dans deux salons) : on en crée
    -- une neuve plutôt que d'en choisir une au hasard. Le gérant rattachera.
    INSERT INTO public.profiles (user_id, salon_id, full_name, email, role)
    VALUES (
      NEW.id,
      v_salon_id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'role', 'coiffeur')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RESTE À FAIRE : `create_salon_for_signup` est appelable sans authentification
-- et sans plafond. Une edge function limitant les appels par IP est nécessaire
-- avant l'ouverture publique de l'app.
