-- Corrige l'inscription : le salon est créé AVANT le signUp, donc par un
-- utilisateur encore anonyme. L'ancienne policy (TO authenticated) le bloquait.
--
-- On sépare les droits :
--   - INSERT ouvert à anon (nécessaire au parcours d'inscription 1.3 → 1.4)
--   - lecture / modification / suppression réservées aux comptes connectés

DROP POLICY IF EXISTS "Authenticated users full access to salons" ON public.salons;
DROP POLICY IF EXISTS "Allow public full access to salons" ON public.salons;

-- Création du salon pendant l'inscription (utilisateur pas encore authentifié)
CREATE POLICY "Anyone can create a salon during signup"
  ON public.salons FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- Lecture / écriture une fois le compte créé
CREATE POLICY "Authenticated users can read salons"
  ON public.salons FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can update salons"
  ON public.salons FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete salons"
  ON public.salons FOR DELETE TO authenticated
  USING (true);

-- `.insert().select().single()` a besoin de relire la ligne juste insérée,
-- ce que la policy SELECT ci-dessus n'autorise pas pour un anon.
-- On expose donc la création via une fonction SECURITY DEFINER si besoin.
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
  INSERT INTO public.salons (name, phone, address)
  VALUES (p_name, p_phone, p_address)
  RETURNING * INTO v_salon;
  RETURN v_salon;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_salon_for_signup(TEXT, TEXT, TEXT)
  TO anon, authenticated;
