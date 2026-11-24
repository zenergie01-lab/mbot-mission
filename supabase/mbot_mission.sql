-- =====================================================================
--  mBot Mission — classement en ligne (Supabase auto-hébergé)
--  À coller dans Supabase Studio > SQL Editor, puis « Run ».
--  Le script peut être relancé sans risque (idempotent).
--
--  Données minimales (RGPD) : prénom + initiale, classe, code de classe,
--  points de jeu, apparence du robot. Pas de nom de famille, pas d'e-mail,
--  pas de mot de passe, pas d'adresse IP stockée dans ces tables.
--
--  Sécurité : les tables sont dans le schéma « mbot », invisible depuis l'API.
--  Le jeu n'a accès qu'à 3 fonctions (RPC) du schéma public, avec la clé anon.
-- =====================================================================

create schema if not exists mbot;

-- Codes de classe / d'établissement créés par le professeur
create table if not exists mbot.codes (
  code           text primary key check (code = upper(code) and char_length(code) between 4 and 30),
  etablissement  text not null check (char_length(etablissement) between 2 and 80),
  actif          boolean not null default true,
  cree_le        timestamptz not null default now()
);

-- Une ligne par élève (clé : code + classe + prénom)
create table if not exists mbot.joueurs (
  code        text not null references mbot.codes(code) on delete cascade,
  classe      text not null check (char_length(classe) between 1 and 15),
  prenom      text not null check (char_length(prenom) between 1 and 20),
  xp          integer not null default 0 check (xp between 0 and 50000),
  etoiles     integer not null default 0 check (etoiles between 0 and 60),
  ceintures   integer not null default 0 check (ceintures between 0 and 6),
  trophees    integer not null default 0 check (trophees between 0 and 60),
  couleur     text not null default 'bleu' check (char_length(couleur) <= 20),
  chapeau     text not null default 'aucun' check (char_length(chapeau) <= 20),
  maj_le      timestamptz not null default now(),
  primary key (code, classe, prenom)
);
create index if not exists joueurs_classement on mbot.joueurs (code, xp desc);

-- Personne n'accède directement aux tables depuis l'API
alter table mbot.codes   enable row level security;
alter table mbot.joueurs enable row level security;
revoke all on schema mbot from public;
revoke all on all tables in schema mbot from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on schema mbot from anon, authenticated';
    execute 'revoke all on all tables in schema mbot from anon, authenticated';
  end if;
end $$;

-- 1) Envoyer ses points (garde toujours le meilleur score)
create or replace function public.mbot_envoyer(
  p_code text, p_prenom text, p_classe text, p_xp integer, p_etoiles integer,
  p_ceintures integer, p_trophees integer, p_couleur text, p_chapeau text)
returns text
language plpgsql
security definer
set search_path = mbot, pg_temp
as $$
declare
  v_code   text := upper(btrim(coalesce(p_code, '')));
  v_prenom text := left(regexp_replace(btrim(coalesce(p_prenom, '')), '\s+', ' ', 'g'), 20);
  v_classe text := upper(left(btrim(coalesce(p_classe, '')), 15));
begin
  if not exists (select 1 from mbot.codes c where c.code = v_code and c.actif) then
    return 'code_inconnu';
  end if;
  if v_prenom = '' or v_classe = '' then
    return 'incomplet';
  end if;
  insert into mbot.joueurs as j (code, classe, prenom, xp, etoiles, ceintures, trophees, couleur, chapeau, maj_le)
  values (v_code, v_classe, v_prenom,
          least(greatest(coalesce(p_xp, 0), 0), 50000),
          least(greatest(coalesce(p_etoiles, 0), 0), 60),
          least(greatest(coalesce(p_ceintures, 0), 0), 6),
          least(greatest(coalesce(p_trophees, 0), 0), 60),
          left(coalesce(p_couleur, 'bleu'), 20),
          left(coalesce(p_chapeau, 'aucun'), 20),
          now())
  on conflict (code, classe, prenom) do update set
    xp        = greatest(j.xp, excluded.xp),
    etoiles   = greatest(j.etoiles, excluded.etoiles),
    ceintures = greatest(j.ceintures, excluded.ceintures),
    trophees  = greatest(j.trophees, excluded.trophees),
    couleur   = excluded.couleur,
    chapeau   = excluded.chapeau,
    maj_le    = now();
  return 'ok';
end;
$$;

-- 2) Lire le classement d'un code (200 premiers)
create or replace function public.mbot_classement(p_code text)
returns table (prenom text, classe text, xp integer, etoiles integer, ceintures integer, trophees integer, couleur text, chapeau text)
language sql
stable
security definer
set search_path = mbot, pg_temp
as $$
  select j.prenom, j.classe, j.xp, j.etoiles, j.ceintures, j.trophees, j.couleur, j.chapeau
  from mbot.joueurs j
  join mbot.codes c on c.code = j.code and c.actif
  where j.code = upper(btrim(coalesce(p_code, '')))
  order by j.xp desc, j.etoiles desc, j.maj_le asc
  limit 200;
$$;

-- 3) Nom de l'établissement associé à un code (pour l'affichage)
create or replace function public.mbot_etablissement(p_code text)
returns text
language sql
stable
security definer
set search_path = mbot, pg_temp
as $$
  select c.etablissement from mbot.codes c where c.code = upper(btrim(coalesce(p_code, ''))) and c.actif;
$$;

revoke all on function public.mbot_envoyer(text, text, text, integer, integer, integer, integer, text, text) from public;
revoke all on function public.mbot_classement(text) from public;
revoke all on function public.mbot_etablissement(text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'grant execute on function public.mbot_envoyer(text, text, text, integer, integer, integer, integer, text, text) to anon, authenticated';
    execute 'grant execute on function public.mbot_classement(text) to anon, authenticated';
    execute 'grant execute on function public.mbot_etablissement(text) to anon, authenticated';
  end if;
end $$;

-- =====================================================================
--  À PERSONNALISER : ton code de classe et le nom de ton établissement.
--  Donne ce code aux élèves (un seul code pour tout l'établissement suffit :
--  le classement se filtre ensuite par classe dans le jeu).
-- =====================================================================
insert into mbot.codes (code, etablissement)
values ('TECHNO-KOUROU-2026', 'Mon collège')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
--  Gestion courante (à lancer à la main, une ligne à la fois)
-- ---------------------------------------------------------------------
-- Voir le classement :            select * from public.mbot_classement('TECHNO-KOUROU-2026');
-- Effacer un élève :              delete from mbot.joueurs where code = 'TECHNO-KOUROU-2026' and classe = '3_GOYA' and prenom = 'Léa M.';
-- Fermer les envois (fin d'année): update mbot.codes set actif = false where code = 'TECHNO-KOUROU-2026';
-- Tout effacer en fin d'année :   delete from mbot.joueurs where code = 'TECHNO-KOUROU-2026';
