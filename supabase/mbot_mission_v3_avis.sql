-- =====================================================================
--  mBot Mission — mise à jour v3 : avis et commentaires
--  À lancer APRÈS mbot_mission_v2_chrono_ligue.sql (idempotent).
--
--  Les avis sont rangés dans mbot.avis. Personne ne peut les lire depuis
--  le jeu : seul le professeur les lit dans Supabase Studio.
-- =====================================================================

create table if not exists mbot.avis (
  id          bigint generated always as identity primary key,
  cree_le     timestamptz not null default now(),
  profil      text not null,          -- eleve, enseignant, parent, autre
  sujet       text not null,          -- jeu, niveaux, programme, vrai_mbot, classement, bug, idee, autre
  note        smallint,               -- 1 à 5 étoiles (facultatif)
  difficulte  text,                   -- trop_facile, bien, trop_dur (facultatif)
  message     text not null,
  contact     text,                   -- courriel, enseignants seulement, facultatif
  etablissement text,                 -- déduit du code du collège, si l'élève en a un
  classe      text,
  niveau      text,                   -- circuit en cours (n1…n17)
  traite      boolean not null default false,
  reponse     text                    -- note du professeur (suite donnée)
);
alter table mbot.avis enable row level security;
revoke all on mbot.avis from anon, authenticated;

create or replace function public.mbot_avis(
  p_profil text, p_sujet text, p_note integer, p_difficulte text,
  p_message text, p_contact text default null, p_code text default null,
  p_classe text default null, p_niveau text default null)
returns text
language plpgsql
security definer
set search_path = mbot, pg_temp
as $$
declare
  v_profil text := lower(btrim(coalesce(p_profil, '')));
  v_sujet  text := lower(btrim(coalesce(p_sujet, '')));
  v_msg    text := left(btrim(coalesce(p_message, '')), 1500);
  v_diff   text := nullif(lower(btrim(coalesce(p_difficulte, ''))), '');
  v_contact text := nullif(left(btrim(coalesce(p_contact, '')), 120), '');
  v_etab   text;
begin
  if v_profil not in ('eleve', 'enseignant', 'parent', 'autre') then return 'profil'; end if;
  if v_sujet not in ('jeu', 'niveaux', 'programme', 'vrai_mbot', 'classement', 'duel', 'garage', 'bug', 'idee', 'autre') then return 'sujet'; end if;
  if length(v_msg) < 5 then return 'message'; end if;
  if v_diff is not null and v_diff not in ('trop_facile', 'bien', 'trop_dur') then v_diff := null; end if;
  -- un élève ne laisse pas de coordonnées (RGPD)
  if v_profil = 'eleve' then v_contact := null; end if;
  -- frein anti-abus : 40 avis maximum par tranche de 10 minutes, tous postes confondus
  if (select count(*) from mbot.avis where cree_le > now() - interval '10 minutes') >= 40 then return 'trop'; end if;
  select c.etablissement into v_etab from mbot.codes c where c.code = upper(btrim(coalesce(p_code, ''))) and c.actif;
  insert into mbot.avis (profil, sujet, note, difficulte, message, contact, etablissement, classe, niveau)
  values (v_profil, v_sujet,
          case when p_note between 1 and 5 then p_note end,
          v_diff, v_msg, v_contact, v_etab,
          nullif(upper(left(btrim(coalesce(p_classe, '')), 15)), ''),
          case when p_niveau ~ '^n[0-9]{1,2}$' then p_niveau end);
  return 'ok';
end;
$$;

revoke all on function public.mbot_avis(text, text, integer, text, text, text, text, text, text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'grant execute on function public.mbot_avis(text, text, integer, text, text, text, text, text, text) to anon, authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------------
--  Lire les avis (Supabase Studio > SQL Editor, ou Table Editor > schéma mbot > avis)
-- ---------------------------------------------------------------------
-- Les nouveaux avis :
--   select cree_le, profil, sujet, note, difficulte, message, contact, etablissement, classe, niveau
--   from mbot.avis where not traite order by cree_le desc;
-- Moyenne des notes par profil :
--   select profil, count(*), round(avg(note), 1) from mbot.avis group by profil;
-- Marquer un avis comme traité :
--   update mbot.avis set traite = true, reponse = 'corrigé le 02/12' where id = 12;
-- Effacer les avis en fin d'année :
--   delete from mbot.avis;
