// Copie toutes les photos du stockage « shop-media » (logos, couvertures, produits) dans le dossier donné.
// Bucket public : liste et téléchargement avec la clé publique, lues dans js/config.js.
import fs from 'fs';
import path from 'path';

const cfg = fs.readFileSync('js/config.js', 'utf8');
const val = k => cfg.match(new RegExp(k + " *= *'([^']*)'"))[1];
const URL = val('SUPABASE_URL'), KEY = val('SUPABASE_ANON_KEY'), out = process.argv[2];
const H = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

// La liste n'est pas récursive : les dossiers (sans id) sont parcourus un par un.
async function walk(prefix) {
  const files = [];
  for (let offset = 0; ; offset += 1000) {
    const r = await fetch(`${URL}/storage/v1/object/list/shop-media`, { method: 'POST', headers: H, body: JSON.stringify({ prefix, limit: 1000, offset }) });
    if (!r.ok) throw new Error(`Liste impossible (${prefix || 'racine'}) : ${r.status} ${await r.text()}`);
    const L = await r.json();
    for (const x of L) {
      const p = prefix ? `${prefix}/${x.name}` : x.name;
      if (x.id) files.push(p); else files.push(...await walk(p));
    }
    if (L.length < 1000) return files;
  }
}

const files = await walk('');
let bytes = 0;
for (const p of files) {
  const r = await fetch(`${URL}/storage/v1/object/public/shop-media/${p.split('/').map(encodeURIComponent).join('/')}`);
  if (!r.ok) throw new Error(`Téléchargement impossible : ${p} (${r.status})`);
  const b = Buffer.from(await r.arrayBuffer());
  fs.mkdirSync(path.dirname(path.join(out, p)), { recursive: true });
  fs.writeFileSync(path.join(out, p), b);
  bytes += b.length;
}
console.log(`${files.length} photo(s), ${(bytes / 1024 / 1024).toFixed(1)} Mo`);
