-- Permettre au gérant de créer un employé (écran « Nouvel employé »).
--
-- Blocage levé ici : `profiles.id` référençait `auth.users(id)`, donc un profil
-- ne pouvait pas exister sans compte Auth — et créer un compte Auth depuis
-- l'app exige la clé service role (impossible côté client) ou un `signUp` qui
-- remplacerait la session du gérant.
--
-- Nouveau modèle : le profil est autonome, le compte s'y rattache ensuite via
-- `user_id`. La plupart des coiffeurs n'ouvriront jamais l'app ; ils doivent
-- malgré tout figurer au planning et toucher leurs commissions.

-- 1. Le profil ne dépend plus d'un compte Auth.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.profiles ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 2. Lien optionnel vers le compte Auth + email de rattachement.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS email TEXT;

-- 3. Rétro-compatibilité : jusqu'ici `profiles.id` ÉTAIT l'id du compte.
UPDATE public.profiles SET user_id = id WHERE user_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_user ON public.profiles(user_id);

-- 4. À l'inscription, réclamer la fiche pré-créée par le gérant si elle existe,
--    au lieu d'en créer une seconde en doublon.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_salon_id UUID := (NEW.raw_user_meta_data->>'salon_id')::uuid;
  v_claimed  UUID;
BEGIN
  SELECT id INTO v_claimed
    FROM public.profiles
   WHERE user_id IS NULL
     AND email IS NOT NULL
     AND lower(email) = lower(NEW.email)
     AND (v_salon_id IS NULL OR salon_id = v_salon_id)
   LIMIT 1;

  IF v_claimed IS NOT NULL THEN
    UPDATE public.profiles
       SET user_id   = NEW.id,
           full_name = COALESCE(
             NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
             full_name
           )
     WHERE id = v_claimed;
  ELSE
    -- `role` par défaut : 'coiffeur'. L'ancienne version écrivait 'stylist',
    -- valeur inconnue de l'enum UserRole côté Flutter.
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

-- 5. Corriger les rôles écrits par l'ancienne version du trigger.
UPDATE public.profiles SET role = 'coiffeur' WHERE role = 'stylist';
