-- =====================================================================
--  mBot Mission — mise à jour v2 : chronomètre + ligue des 6 collèges
--  À lancer APRÈS mbot_mission.sql (idempotent : peut être relancé).
--
--  Ajoute :
--   - les meilleurs temps par niveau (colonne temps, en secondes) ;
--   - les classements anonymes par classe et par collège (ligue) :
--     aucun prénom n'est visible d'un collège à l'autre, et un groupe
--     n'apparaît qu'à partir de 3 joueurs ;
--   - un code par collège (6 collèges de l'Ouest guyanais).
-- =====================================================================

alter table mbot.joueurs add column if not exists temps jsonb not null default '{}'::jsonb;

-- Changer un code met à jour automatiquement les élèves qui l'utilisent
alter table mbot.joueurs drop constraint if exists joueurs_code_fkey;
alter table mbot.joueurs add constraint joueurs_code_fkey foreign key (code) references mbot.codes(code) on delete cascade on update cascade;

-- 1) Envoyer ses points et ses meilleurs temps (garde toujours le meilleur)
drop function if exists public.mbot_envoyer(text, text, text, integer, integer, integer, integer, text, text);
create or replace function public.mbot_envoyer(
  p_code text, p_prenom text, p_classe text, p_xp integer, p_etoiles integer,
  p_ceintures integer, p_trophees integer, p_couleur text, p_chapeau text,
  p_temps jsonb default '{}'::jsonb)
returns text
language plpgsql
security definer
set search_path = mbot, pg_temp
as $$
declare
  v_code   text := upper(btrim(coalesce(p_code, '')));
  v_prenom text := left(regexp_replace(btrim(coalesce(p_prenom, '')), '\s+', ' ', 'g'), 20);
  v_classe text := upper(left(btrim(coalesce(p_classe, '')), 15));
  v_temps  jsonb := '{}'::jsonb;
  k text; v jsonb; n integer;
begin
  if not exists (select 1 from mbot.codes c where c.code = v_code and c.actif) then
    return 'code_inconnu';
  end if;
  if v_prenom = '' or v_classe = '' then
    return 'incomplet';
  end if;
  -- temps : clés n1..n99, valeurs entières entre 3 s et 10 h
  if p_temps is not null and jsonb_typeof(p_temps) = 'object' then
    for k, v in select * from jsonb_each(p_temps) loop
      if k ~ '^n[0-9]{1,2}$' and jsonb_typeof(v) = 'number' then
        n := round((v #>> '{}')::numeric)::integer;
        if n between 3 and 36000 then
          v_temps := v_temps || jsonb_build_object(k, n);
        end if;
      end if;
    end loop;
  end if;
  insert into mbot.joueurs as j (code, classe, prenom, xp, etoiles, ceintures, trophees, couleur, chapeau, temps, maj_le)
  values (v_code, v_classe, v_prenom,
          least(greatest(coalesce(p_xp, 0), 0), 50000),
          least(greatest(coalesce(p_etoiles, 0), 0), 60),
          least(greatest(coalesce(p_ceintures, 0), 0), 6),
          least(greatest(coalesce(p_trophees, 0), 0), 60),
          left(coalesce(p_couleur, 'bleu'), 20),
          left(coalesce(p_chapeau, 'aucun'), 20),
          v_temps, now())
  on conflict (code, classe, prenom) do update set
    xp        = greatest(j.xp, excluded.xp),
    etoiles   = greatest(j.etoiles, excluded.etoiles),
    ceintures = greatest(j.ceintures, excluded.ceintures),
    trophees  = greatest(j.trophees, excluded.trophees),
    couleur   = excluded.couleur,
    chapeau   = excluded.chapeau,
    temps     = (select coalesce(jsonb_object_agg(t.cle, t.val), '{}'::jsonb)
                 from (select u.cle, min(u.val) as val
                       from (select e.key as cle, (e.value #>> '{}')::integer as val from jsonb_each(j.temps) e
                             union all
                             select e.key, (e.value #>> '{}')::integer from jsonb_each(excluded.temps) e) u
                       group by u.cle) t),
    maj_le    = now();
  return 'ok';
end;
$$;

-- 2) Classement d'un collège (prénoms visibles uniquement entre élèves du même code)
drop function if exists public.mbot_classement(text);
create or replace function public.mbot_classement(p_code text)
returns table (prenom text, classe text, xp integer, etoiles integer, ceintures integer, trophees integer, couleur text, chapeau text, temps jsonb)
language sql
stable
security definer
set search_path = mbot, pg_temp
as $$
  select j.prenom, j.classe, j.xp, j.etoiles, j.ceintures, j.trophees, j.couleur, j.chapeau, j.temps
  from mbot.joueurs j
  join mbot.codes c on c.code = j.code and c.actif
  where j.code = upper(btrim(coalesce(p_code, '')))
  order by j.xp desc, j.etoiles desc, j.maj_le asc
  limit 300;
$$;

-- 3) Ligue des collèges (anonyme, 3 joueurs minimum)
create or replace function public.mbot_ligue_colleges()
returns table (etablissement text, joueurs integer, xp_moyen integer, xp_total integer, etoiles integer, ceintures integer)
language sql
stable
security definer
set search_path = mbot, pg_temp
as $$
  select c.etablissement, count(*)::integer, round(avg(j.xp))::integer, sum(j.xp)::integer,
         sum(j.etoiles)::integer, sum(j.ceintures)::integer
  from mbot.joueurs j
  join mbot.codes c on c.code = j.code and c.actif
  group by c.etablissement
  having count(*) >= 3
  order by avg(j.xp) desc;
$$;

-- 4) Ligue des classes (anonyme, 3 joueurs minimum)
create or replace function public.mbot_ligue_classes()
returns table (etablissement text, classe text, joueurs integer, xp_moyen integer, etoiles integer)
language sql
stable
security definer
set search_path = mbot, pg_temp
as $$
  select c.etablissement, j.classe, count(*)::integer, round(avg(j.xp))::integer, sum(j.etoiles)::integer
  from mbot.joueurs j
  join mbot.codes c on c.code = j.code and c.actif
  group by c.etablissement, j.classe
  having count(*) >= 3
  order by avg(j.xp) desc
  limit 150;
$$;

revoke all on function public.mbot_envoyer(text, text, text, integer, integer, integer, integer, text, text, jsonb) from public;
revoke all on function public.mbot_classement(text) from public;
revoke all on function public.mbot_ligue_colleges() from public;
revoke all on function public.mbot_ligue_classes() from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'grant execute on function public.mbot_envoyer(text, text, text, integer, integer, integer, integer, text, text, jsonb) to anon, authenticated';
    execute 'grant execute on function public.mbot_classement(text) to anon, authenticated';
    execute 'grant execute on function public.mbot_ligue_colleges() to anon, authenticated';
    execute 'grant execute on function public.mbot_ligue_classes() to anon, authenticated';
  end if;
end $$;

-- 5) Un code par collège (à donner aux élèves de chaque collège)
insert into mbot.codes (code, etablissement) values
  ('OMEBA-7XUH',      'Collège Omeba Tobo — Kourou'),
  ('AGARANDE-VT8H',   'Collège Henri Agarande — Kourou'),
  ('SCHOELCHER-VWJB', 'Collège Victor Schoelcher — Kourou'),
  ('HOTENYOU-2QAW',   'Collège Joseph Ho-Ten-You — Kourou'),
  ('MADELEINE-5RZ3',  'Collège Ferdinand Madeleine — Iracoubo'),
  ('CASTOR-Z9WR',     'Collège Élie Castor — Sinnamary')
on conflict (code) do update set etablissement = excluded.etablissement, actif = true;

-- L'ancien code d'essai n'est plus utilisé
update mbot.codes set actif = false where code = 'TECHNO-KOUROU-2026';

-- ---------------------------------------------------------------------
--  Gestion courante (dans Supabase Studio > SQL Editor)
-- ---------------------------------------------------------------------
-- Voir les codes :                select * from mbot.codes order by etablissement;
-- Changer un code :               update mbot.codes set code = 'NOUVEAU-CODE' where code = 'OMEBA-7XUH';
--                                 (les élèves déjà inscrits suivent automatiquement)
-- Renommer un collège :           update mbot.codes set etablissement = 'Nouveau nom' where code = 'OMEBA-7XUH';
-- Ajouter un collège :            insert into mbot.codes (code, etablissement) values ('NOM-ABCD', 'Collège … — Ville');
-- Fermer un collège (fin d'année): update mbot.codes set actif = false where code = 'OMEBA-7XUH';
-- Voir un classement :            select * from public.mbot_classement('OMEBA-7XUH');
-- Ligue des collèges :            select * from public.mbot_ligue_colleges();
-- Effacer un élève :              delete from mbot.joueurs where code = 'OMEBA-7XUH' and classe = '3_GOYA' and prenom = 'Léa M.';
-- Tout effacer en fin d'année :   delete from mbot.joueurs;
