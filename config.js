// Configuration du classement en ligne (Supabase auto-hébergé).
// La clé « anon » est publique par conception : elle ne donne accès
// qu'aux 3 fonctions mbot_* créées par supabase/mbot_mission.sql.
// Laisse « cle » vide pour désactiver le classement en ligne.
window.MBOT_CONFIG = {
  url: 'https://supabase.automatisationconsciente.fr',
  cle: ''
};
