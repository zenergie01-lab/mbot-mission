// Relais vers le classement Supabase (évite le blocage CORS et garde la clé côté serveur).
// Seules les 3 fonctions du jeu sont autorisées.
const AUTORISEES = new Set(['mbot_envoyer', 'mbot_classement', 'mbot_etablissement']);

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ erreur: 'POST uniquement' });
  const fn = String((req.query && req.query.fn) || '');
  if (!AUTORISEES.has(fn)) return res.status(400).json({ erreur: 'fonction inconnue' });
  const url = process.env.SUPABASE_URL, cle = process.env.SUPABASE_ANON_KEY;
  if (!url || !cle) return res.status(503).json({ erreur: 'classement non configuré' });
  const corps = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
  if (corps.length > 2000) return res.status(413).json({ erreur: 'requête trop grande' });
  try {
    const r = await fetch(url.replace(/\/$/, '') + '/rest/v1/rpc/' + fn, {
      method: 'POST',
      headers: { apikey: cle, Authorization: 'Bearer ' + cle, 'Content-Type': 'application/json' },
      body: corps
    });
    const texte = await r.text();
    res.status(r.status).setHeader('Content-Type', 'application/json');
    return res.send(texte);
  } catch (e) {
    return res.status(502).json({ erreur: 'serveur de classement injoignable' });
  }
};
