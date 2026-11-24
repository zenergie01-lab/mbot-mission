// Classement en ligne : le jeu passe par le relais /api/rpc (fonction Vercel),
// qui ajoute la clé Supabase côté serveur (variables SUPABASE_URL et SUPABASE_ANON_KEY).
// Pour une version hors ligne (fichier ouvert sur le poste), mettre proxy: ''.
window.MBOT_CONFIG = { proxy: '/api/rpc' };
