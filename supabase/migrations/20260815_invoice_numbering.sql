-- Numérotation continue des factures, par salon et par année.
--
-- Le numéro était jusqu'ici dérivé de l'identifiant de la transaction :
-- stable et unique, mais pas séquentiel. Or une comptabilité attend une suite
-- continue et sans trou, et un client qui reçoit « FA-2026-0261 » puis
-- « FA-2026-0044 » le lendemain a de quoi douter.
--
-- Le compteur est tenu en base parce que c'est le seul endroit où deux caisses
-- encaissant à la même seconde peuvent être départagées : côté client, deux
-- lectures concurrentes du dernier numéro donneraient le même.

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS invoice_seq INTEGER;

-- Un numéro ne vaut que dans son salon et son année : deux salons ont chacun
-- leur facture n° 1, et la suite repart à 1 en janvier.
CREATE TABLE IF NOT EXISTS public.invoice_counters (
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    year     INTEGER NOT NULL,
    next_seq INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (salon_id, year)
);

ALTER TABLE public.invoice_counters ENABLE ROW LEVEL SECURITY;

-- Aucune politique permissive : la table n'est touchée que par le déclencheur,
-- qui s'exécute en `SECURITY DEFINER`. Personne n'a à la lire ni à l'écrire
-- depuis l'application — pouvoir reculer un compteur, c'est pouvoir réémettre
-- un numéro déjà utilisé.

-- Deux factures ne peuvent pas porter le même numéro dans un salon.
CREATE UNIQUE INDEX IF NOT EXISTS transactions_invoice_seq_key
  ON public.transactions (salon_id, invoice_seq)
  WHERE invoice_seq IS NOT NULL;

CREATE OR REPLACE FUNCTION public.assign_invoice_seq()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year INTEGER := EXTRACT(YEAR FROM COALESCE(NEW.created_at, now()))::INTEGER;
BEGIN
  -- Un brouillon n'est pas une facture : le numéro n'est attribué qu'au
  -- règlement, sinon un panier abandonné consommerait un rang et laisserait
  -- un trou dans la suite.
  IF NEW.status IS DISTINCT FROM 'paid' OR NEW.invoice_seq IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- `ON CONFLICT … DO UPDATE` sérialise : la seconde transaction attend le
  -- verrou de ligne, puis lit le compteur déjà incrémenté.
  INSERT INTO public.invoice_counters (salon_id, year, next_seq)
  VALUES (NEW.salon_id, v_year, 2)
  ON CONFLICT (salon_id, year)
  DO UPDATE SET next_seq = public.invoice_counters.next_seq + 1
  RETURNING next_seq - 1 INTO NEW.invoice_seq;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS transactions_assign_invoice_seq ON public.transactions;
CREATE TRIGGER transactions_assign_invoice_seq
  BEFORE INSERT OR UPDATE OF status ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_invoice_seq();

-- Rattrapage des transactions déjà encaissées : numérotées par salon, par
-- année, dans l'ordre où elles ont été créées.
DO $$
DECLARE
  v_row RECORD;
BEGIN
  FOR v_row IN
    SELECT id,
           salon_id,
           EXTRACT(YEAR FROM created_at)::INTEGER AS yr,
           row_number() OVER (
             PARTITION BY salon_id, EXTRACT(YEAR FROM created_at)
             ORDER BY created_at, id
           ) AS seq
      FROM public.transactions
     WHERE status = 'paid'
       AND invoice_seq IS NULL
  LOOP
    UPDATE public.transactions
       SET invoice_seq = v_row.seq
     WHERE id = v_row.id;

    INSERT INTO public.invoice_counters (salon_id, year, next_seq)
    VALUES (v_row.salon_id, v_row.yr, v_row.seq + 1)
    ON CONFLICT (salon_id, year)
    DO UPDATE SET next_seq = GREATEST(
      public.invoice_counters.next_seq,
      EXCLUDED.next_seq
    );
  END LOOP;
END;
$$;
