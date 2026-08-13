-- Codes d'invitation de salon — parcours « Rejoindre un salon » du prototype.
--
-- Le gérant crée la fiche employé (email + rôle), puis dicte à la personne le
-- code à six caractères du salon. À l'inscription, le code désigne le salon et
-- la fiche pré-créée est réclamée : le rôle vient de la fiche, jamais du client.

-- ==========================================
-- 1. Colonne `invite_code` sur `salons`
-- ==========================================

-- Alphabet sans caractères ambigus (ni 0/O, ni 1/I/L) : le code est dicté à
-- l'oral ou recopié depuis un SMS.
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code TEXT;
  v_try INTEGER := 0;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(
        v_alphabet,
        1 + floor(random() * length(v_alphabet))::int,
        1
      );
    END LOOP;

    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.salons WHERE upper(invite_code) = v_code
    );

    v_try := v_try + 1;
    IF v_try > 50 THEN
      RAISE EXCEPTION 'Impossible de générer un code d''invitation unique';
    END IF;
  END LOOP;

  RETURN v_code;
END;
$$;

ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS invite_code TEXT;

-- Les salons déjà en base n'en ont pas : un par un, le générateur vérifiant
-- l'unicité au fur et à mesure.
DO $$
DECLARE
  v_id UUID;
BEGIN
  FOR v_id IN SELECT id FROM public.salons WHERE invite_code IS NULL LOOP
    UPDATE public.salons
       SET invite_code = public.generate_invite_code()
     WHERE id = v_id;
  END LOOP;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS salons_invite_code_key
  ON public.salons (upper(invite_code));

ALTER TABLE public.salons
  ALTER COLUMN invite_code SET DEFAULT public.generate_invite_code();
ALTER TABLE public.salons
  ALTER COLUMN invite_code SET NOT NULL;

-- ==========================================
-- 2. Résolution du code avant inscription
-- ==========================================

-- Appelée par un visiteur encore anonyme, sur l'écran « Rejoindre un salon » :
-- elle ne renvoie que le nom, de quoi confirmer « Salon reconnu ». Le code seul
-- ne donne aucun accès — l'inscription exige en plus une fiche employé.
CREATE OR REPLACE FUNCTION public.salon_by_invite_code(p_code TEXT)
RETURNS TABLE (id UUID, name TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.id, s.name
    FROM public.salons s
   WHERE upper(s.invite_code) = upper(btrim(coalesce(p_code, '')))
     AND btrim(coalesce(p_code, '')) <> '';
$$;

GRANT EXECUTE ON FUNCTION public.salon_by_invite_code(TEXT) TO anon, authenticated;

-- ==========================================
-- 3. Rattachement à l'inscription
-- ==========================================

-- Remplace la version de `20260812_harden_rls_and_signup` en ajoutant la
-- branche « code d'invitation ».
--
-- Le salon vient du code, résolu ici : un `salon_id` posé par le client ne peut
-- donc pas servir à s'inviter dans un salon tiers. Et sans fiche employé
-- correspondant à l'email, l'inscription est refusée — sinon deviner un code à
-- six caractères suffirait à entrer dans le salon.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_join_code TEXT := upper(btrim(coalesce(NEW.raw_user_meta_data->>'join_code', '')));
  v_salon_id  UUID := (NEW.raw_user_meta_data->>'salon_id')::uuid;
  v_claimed   UUID;
  v_matches   INTEGER;
BEGIN
  IF v_join_code <> '' THEN
    SELECT s.id INTO v_salon_id
      FROM public.salons s
     WHERE upper(s.invite_code) = v_join_code;

    IF v_salon_id IS NULL THEN
      RAISE EXCEPTION 'Code d''invitation inconnu'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Sans `salon_id` transmis, plusieurs salons peuvent avoir pré-créé une fiche
  -- avec le même email. On ne réclame que s'il n'y a aucune ambiguïté : un
  -- `LIMIT 1` arbitraire rattacherait la personne au mauvais salon.
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

  IF v_join_code <> '' AND v_claimed IS NULL THEN
    RAISE EXCEPTION 'Aucune fiche employé n''attend cet email dans ce salon'
      USING ERRCODE = 'check_violation';
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
$$;
