-- `adjust_stock` écrivait dans des colonnes inexistantes.
--
-- La fonction insérait un mouvement avec `type` et `created_by`, alors que
-- `stock_movements` porte `reason`, `occurred_at`, `product_name`,
-- `unit_label`, `context_label` et `cost_fcfa`. Vérifié sur la base :
--
--   stock_movements.type       -> 42703 column does not exist
--   stock_movements.created_by -> 42703 column does not exist
--
-- L'insertion échouait donc systématiquement, et comme une fonction plpgsql
-- est une seule transaction, l'`UPDATE products` était annulé avec elle : le
-- stock ne bougeait jamais. Côté app, l'erreur était avalée par un `catch`,
-- ce qui rendait la panne silencieuse — le bouton « Ouvrir » semblait
-- fonctionner sans rien changer.
--
-- Deux corrections de fond au passage :
--
--  * la quantité est signée. Sans colonne `type` pour porter le sens, c'est
--    le signe qui distingue une réception d'une consommation — ce que la
--    lecture Dart attend déjà (`StockMovement.quantity` négatif en sortie) ;
--  * `cost_fcfa` est renseigné depuis le coût d'achat du produit. C'est la
--    seule source du « coût produits consommés » du mois, qui serait resté
--    à zéro quand bien même l'insertion aurait réussi.

CREATE OR REPLACE FUNCTION public.adjust_stock(
  p_product_id UUID,
  p_delta INT,
  p_reason TEXT DEFAULT 'adjustment',
  p_created_by UUID DEFAULT NULL,
  p_context TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salon_id  UUID;
  v_name      TEXT;
  v_unit_cost INTEGER;
BEGIN
  SELECT salon_id, name, COALESCE(unit_cost_fcfa, 0)
    INTO v_salon_id, v_name, v_unit_cost
    FROM public.products
   WHERE id = p_product_id;

  IF v_salon_id IS NULL THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;

  IF v_salon_id IS DISTINCT FROM public.get_auth_salon_id() THEN
    RAISE EXCEPTION 'Produit inaccessible'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.products
     SET stock_quantity = GREATEST(0, stock_quantity + p_delta)
   WHERE id = p_product_id;

  INSERT INTO public.stock_movements (
    salon_id,
    product_id,
    quantity,
    reason,
    occurred_at,
    product_name,
    context_label,
    cost_fcfa
  ) VALUES (
    v_salon_id,
    p_product_id,
    p_delta,
    p_reason,
    now(),
    v_name,
    p_context,
    ABS(p_delta) * v_unit_cost
  );
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.adjust_stock(UUID, INT, TEXT, UUID, TEXT) TO authenticated;
