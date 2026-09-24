-- ==========================================================================
-- Migration : la lecture seule ne retient pas l'argent de l'équipe
-- ==========================================================================
-- `20260923_read_only_when_expired` posait le trigger sur toutes les tables
-- métier, `payout_requests` et `time_off` comprises. Deux exclusions, pour la
-- même raison : ces lignes ne créent pas de valeur commerciale, et les
-- bloquer frappe quelqu'un d'autre que celui qui n'a pas payé.
--
-- Un versement solde une dette déjà contractée pour un travail déjà fait.
-- L'argent sort du tiroir que la base l'accepte ou non : le refuser ne donne
-- aucune pression de plus sur le gérant, il donne une comptabilité fausse,
-- avec des versements réels à ressaisir après réactivation. Et il pénalise le
-- coiffeur, qui n'a pas la main sur l'abonnement du salon.
--
-- Une demande de congé relève de la même logique, à enjeu moindre : c'est de
-- l'administration du personnel, pas de l'activité commerciale.
--
-- Le verrou garde tout son mordant là où il compte : plus d'encaissement,
-- plus de rendez-vous, plus de client, plus de stock ni de catalogue. Un
-- salon éteint ne peut plus travailler — il peut encore payer son équipe.
--
-- `expenses` reste volontairement bloquée : l'argument « argent déjà sorti »
-- y vaut aussi, mais personne d'autre que le gérant n'en pâtit, et la saisie
-- des dépenses fait partie de ce que la formule facture.

DROP TRIGGER IF EXISTS trg_subscription_required ON public.payout_requests;
DROP TRIGGER IF EXISTS trg_subscription_required ON public.time_off;
