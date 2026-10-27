// Exemples d'affichage, montrés uniquement tant qu'aucune donnée réelle n'existe.
import { ic, toast } from './ui.js';
export const DEMO = {
  cats: [['Mode & Prêt-à-porter','shirt'],['Beauté & Soins','sparkles'],['Maison & Déco','home'],['Alimentation & Épicerie','utensils'],['Artisanat','palette']].map(([name, icon]) => ({ name, icon })),
  products: [['Mame Diarra Créations','Sac à main en cuir','15 000','bag','#4d0c25,#b8893b'],['Lina Cosmétiques','Crème hydratante naturelle','8 000','sparkles','#8a3a52,#e9c9b8'],['Fatou Fashion','Robe en pagne','18 000','shirt','#b8893b,#6a1233'],['Awa Bijoux','Boucles d’oreilles','6 500','gem','#6a1233,#d9b26a']],
  sellers: [['Mame Diarra','Mode & Accessoires'],['Lina','Beauté & Soins'],['Fatou','Mode & Accessoires'],['Awa','Bijoux'],['Ruma','Déco & Maison']].map(([shop_name, location]) => ({ shop_name, location, demo: 1 })),
};
export const demoCard = p => `<div class="p"><div class="ph" style="background:linear-gradient(135deg,${p[4]})">${ic(p[3])}<span class="heart">${ic('heart')}</span></div>
<div class="pb"><b>${p[1]}</b><div class="pr">${p[2]} FCFA</div><div class="sl"><span class="mi">${p[0][0]}</span>${p[0]}</div><div class="acts"><button class="btn" data-demo>Commander</button><button class="btn wa" data-demo>Ajouter au panier</button></div></div></div>`;
document.addEventListener('click', e => { if (e.target.closest('[data-demo]')) toast('Exemple de présentation : les vraies créations des vendeuses arrivent bientôt.'); });
