import{S as We,i as Ye,s as Xe,a as Ze,e as B,c as Qe,b as z,g as le,t as F,d as ce,f as J,h as G,j as xe,o as be,k as et,l as tt,m as nt,n as we,p as q,q as rt,r as at,u as ot,v as W,w as Se,x as Y,y as X,z as Ce}from"./chunks/index-af87de52.js";import{g as Be,f as Fe,s as K,a as ve,i as st}from"./chunks/singletons-8c3bcd10.js";import{R as Je,H as Ee}from"./chunks/control-6eaf9e57.js";import{s as it}from"./chunks/paths-846459bd.js";function lt(r,e){return r==="/"||e==="ignore"?r:e==="never"?r.endsWith("/")?r.slice(0,-1):r:e==="always"&&!r.endsWith("/")?r+"/":r}function ct(r){for(const e in r)r[e]=r[e].replace(/%23/g,"#").replace(/%3[Bb]/g,";").replace(/%2[Cc]/g,",").replace(/%2[Ff]/g,"/").replace(/%3[Ff]/g,"?").replace(/%3[Aa]/g,":").replace(/%40/g,"@").replace(/%26/g,"&").replace(/%3[Dd]/g,"=").replace(/%2[Bb]/g,"+").replace(/%24/g,"$");return r}const ft=["href","pathname","search","searchParams","toString","toJSON"];function ut(r,e){const n=new URL(r);for(const s of ft){let o=n[s];Object.defineProperty(n,s,{get(){return e(),o},enumerable:!0,configurable:!0})}return n[Symbol.for("nodejs.util.inspect.custom")]=(s,o,l)=>l(r,o),pt(n),n}function pt(r){Object.defineProperty(r,"hash",{get(){throw new Error("Cannot access event.url.hash. Consider using `$page.url.hash` inside a component instead")}})}function dt(r){let e=5381;if(typeof r=="string"){let n=r.length;for(;n;)e=e*33^r.charCodeAt(--n)}else if(ArrayBuffer.isView(r)){const n=new Uint8Array(r.buffer,r.byteOffset,r.byteLength);let s=n.length;for(;s;)e=e*33^n[--s]}else throw new TypeError("value must be a string or TypedArray");return(e>>>0).toString(36)}const fe=window.fetch;window.fetch=(r,e)=>{if((r instanceof Request?r.method:(e==null?void 0:e.method)||"GET")!=="GET"){const s=new URL(r instanceof Request?r.url:r.toString(),document.baseURI).href;ie.delete(s)}return fe(r,e)};const ie=new Map;function ht(r,e,n){let o=`script[data-sveltekit-fetched][data-url=${JSON.stringify(r instanceof Request?r.url:r)}]`;(n==null?void 0:n.body)&&(typeof n.body=="string"||ArrayBuffer.isView(n.body))&&(o+=`[data-hash="${dt(n.body)}"]`);const l=document.querySelector(o);if(l!=null&&l.textContent){const{body:t,...f}=JSON.parse(l.textContent),h=l.getAttribute("data-ttl");return h&&ie.set(e,{body:t,init:f,ttl:1e3*Number(h)}),Promise.resolve(new Response(t,f))}return fe(r,n)}function mt(r,e){const n=ie.get(r);if(n){if(performance.now()<n.ttl)return new Response(n.body,n.init);ie.delete(r)}return fe(r,e)}const _t=/^(\.\.\.)?(\w+)(?:=(\w+))?$/;function gt(r){const e=[],n=[];let s=!0;return{pattern:r===""?/^\/$/:new RegExp(`^${r.split(/(?:\/|$)/).filter(wt).map((l,t,f)=>{const h=decodeURIComponent(l),d=/^\[\.\.\.(\w+)(?:=(\w+))?\]$/.exec(h);if(d)return e.push(d[1]),n.push(d[2]),"(?:/(.*))?";const g=t===f.length-1;return h&&"/"+h.split(/\[(.+?)\]/).map((y,S)=>{if(S%2){const U=_t.exec(y);if(!U)throw new Error(`Invalid param: ${y}. Params and matcher names can only have underscores and alphanumeric characters.`);const[,D,V,T]=U;return e.push(V),n.push(T),D?"(.*?)":"([^/]+?)"}return g&&y.includes(".")&&(s=!1),y.normalize().replace(/%5[Bb]/g,"[").replace(/%5[Dd]/g,"]").replace(/#/g,"%23").replace(/\?/g,"%3F").replace(/[.*+?^${}()|[\]\\]/g,"\\$&")}).join("")}).join("")}${s?"/?":""}$`),names:e,types:n}}function wt(r){return!/^\([^)]+\)$/.test(r)}function yt(r,e,n,s){const o={};for(let l=0;l<e.length;l+=1){const t=e[l],f=n[l],h=r[l+1]||"";if(f){const d=s[f];if(!d)throw new Error(`Missing "${f}" param matcher`);if(!d(h))return}o[t]=h}return o}function bt(r,e,n,s){const o=new Set(e);return Object.entries(n).map(([f,[h,d,g]])=>{const{pattern:y,names:S,types:U}=gt(f),D={id:f,exec:V=>{const T=y.exec(V);if(T)return yt(T,S,U,s)},errors:[1,...g||[]].map(V=>r[V]),layouts:[0,...d||[]].map(t),leaf:l(h)};return D.errors.length=D.layouts.length=Math.max(D.errors.length,D.layouts.length),D});function l(f){const h=f<0;return h&&(f=~f),[h,r[f]]}function t(f){return f===void 0?f:[o.has(f),r[f]]}}function vt(r){let e,n,s;var o=r[0][0];function l(t){return{props:{data:t[2],form:t[1]}}}return o&&(e=new o(l(r))),{c(){e&&W(e.$$.fragment),n=B()},l(t){e&&Se(e.$$.fragment,t),n=B()},m(t,f){e&&Y(e,t,f),z(t,n,f),s=!0},p(t,f){const h={};if(f&4&&(h.data=t[2]),f&2&&(h.form=t[1]),o!==(o=t[0][0])){if(e){le();const d=e;F(d.$$.fragment,1,0,()=>{X(d,1)}),ce()}o?(e=new o(l(t)),W(e.$$.fragment),J(e.$$.fragment,1),Y(e,n.parentNode,n)):e=null}else o&&e.$set(h)},i(t){s||(e&&J(e.$$.fragment,t),s=!0)},o(t){e&&F(e.$$.fragment,t),s=!1},d(t){t&&G(n),e&&X(e,t)}}}function Et(r){let e,n,s;var o=r[0][0];function l(t){return{props:{data:t[2],$$slots:{default:[kt]},$$scope:{ctx:t}}}}return o&&(e=new o(l(r))),{c(){e&&W(e.$$.fragment),n=B()},l(t){e&&Se(e.$$.fragment,t),n=B()},m(t,f){e&&Y(e,t,f),z(t,n,f),s=!0},p(t,f){const h={};if(f&4&&(h.data=t[2]),f&523&&(h.$$scope={dirty:f,ctx:t}),o!==(o=t[0][0])){if(e){le();const d=e;F(d.$$.fragment,1,0,()=>{X(d,1)}),ce()}o?(e=new o(l(t)),W(e.$$.fragment),J(e.$$.fragment,1),Y(e,n.parentNode,n)):e=null}else o&&e.$set(h)},i(t){s||(e&&J(e.$$.fragment,t),s=!0)},o(t){e&&F(e.$$.fragment,t),s=!1},d(t){t&&G(n),e&&X(e,t)}}}function kt(r){let e,n,s;var o=r[0][1];function l(t){return{props:{data:t[3],form:t[1]}}}return o&&(e=new o(l(r))),{c(){e&&W(e.$$.fragment),n=B()},l(t){e&&Se(e.$$.fragment,t),n=B()},m(t,f){e&&Y(e,t,f),z(t,n,f),s=!0},p(t,f){const h={};if(f&8&&(h.data=t[3]),f&2&&(h.form=t[1]),o!==(o=t[0][1])){if(e){le();const d=e;F(d.$$.fragment,1,0,()=>{X(d,1)}),ce()}o?(e=new o(l(t)),W(e.$$.fragment),J(e.$$.fragment,1),Y(e,n.parentNode,n)):e=null}else o&&e.$set(h)},i(t){s||(e&&J(e.$$.fragment,t),s=!0)},o(t){e&&F(e.$$.fragment,t),s=!1},d(t){t&&G(n),e&&X(e,t)}}}function Ge(r){let e,n=r[5]&&Ke(r);return{c(){e=et("div"),n&&n.c(),this.h()},l(s){e=tt(s,"DIV",{id:!0,"aria-live":!0,"aria-atomic":!0,style:!0});var o=nt(e);n&&n.l(o),o.forEach(G),this.h()},h(){we(e,"id","svelte-announcer"),we(e,"aria-live","assertive"),we(e,"aria-atomic","true"),q(e,"position","absolute"),q(e,"left","0"),q(e,"top","0"),q(e,"clip","rect(0 0 0 0)"),q(e,"clip-path","inset(50%)"),q(e,"overflow","hidden"),q(e,"white-space","nowrap"),q(e,"width","1px"),q(e,"height","1px")},m(s,o){z(s,e,o),n&&n.m(e,null)},p(s,o){s[5]?n?n.p(s,o):(n=Ke(s),n.c(),n.m(e,null)):n&&(n.d(1),n=null)},d(s){s&&G(e),n&&n.d()}}}function Ke(r){let e;return{c(){e=rt(r[6])},l(n){e=at(n,r[6])},m(n,s){z(n,e,s)},p(n,s){s&64&&ot(e,n[6])},d(n){n&&G(e)}}}function Rt(r){let e,n,s,o,l;const t=[Et,vt],f=[];function h(g,y){return g[0][1]?0:1}e=h(r),n=f[e]=t[e](r);let d=r[4]&&Ge(r);return{c(){n.c(),s=Ze(),d&&d.c(),o=B()},l(g){n.l(g),s=Qe(g),d&&d.l(g),o=B()},m(g,y){f[e].m(g,y),z(g,s,y),d&&d.m(g,y),z(g,o,y),l=!0},p(g,[y]){let S=e;e=h(g),e===S?f[e].p(g,y):(le(),F(f[S],1,1,()=>{f[S]=null}),ce(),n=f[e],n?n.p(g,y):(n=f[e]=t[e](g),n.c()),J(n,1),n.m(s.parentNode,s)),g[4]?d?d.p(g,y):(d=Ge(g),d.c(),d.m(o.parentNode,o)):d&&(d.d(1),d=null)},i(g){l||(J(n),l=!0)},o(g){F(n),l=!1},d(g){f[e].d(g),g&&G(s),d&&d.d(g),g&&G(o)}}}function St(r,e,n){let{stores:s}=e,{page:o}=e,{components:l}=e,{form:t}=e,{data_0:f=null}=e,{data_1:h=null}=e;xe(s.page.notify);let d=!1,g=!1,y=null;return be(()=>{const S=s.page.subscribe(()=>{d&&(n(5,g=!0),n(6,y=document.title||"untitled page"))});return n(4,d=!0),S}),r.$$set=S=>{"stores"in S&&n(7,s=S.stores),"page"in S&&n(8,o=S.page),"components"in S&&n(0,l=S.components),"form"in S&&n(1,t=S.form),"data_0"in S&&n(2,f=S.data_0),"data_1"in S&&n(3,h=S.data_1)},r.$$.update=()=>{r.$$.dirty&384&&s.page.set(o)},[l,t,f,h,d,g,y,s,o]}class Ot extends We{constructor(e){super(),Ye(this,e,St,Rt,Xe,{stores:7,page:8,components:0,form:1,data_0:2,data_1:3})}}const It=function(){const e=document.createElement("link").relList;return e&&e.supports&&e.supports("modulepreload")?"modulepreload":"preload"}(),Lt=function(r,e){return new URL(r,e).href},ze={},M=function(e,n,s){return!n||n.length===0?e():Promise.all(n.map(o=>{if(o=Lt(o,s),o in ze)return;ze[o]=!0;const l=o.endsWith(".css"),t=l?'[rel="stylesheet"]':"";if(document.querySelector(`link[href="${o}"]${t}`))return;const f=document.createElement("link");if(f.rel=l?"stylesheet":It,l||(f.as="script",f.crossOrigin=""),f.href=o,document.head.appendChild(f),l)return new Promise((h,d)=>{f.addEventListener("load",h),f.addEventListener("error",()=>d(new Error(`Unable to preload CSS for ${o}`)))})})).then(()=>e())},$t={},ue=[()=>M(()=>import("./chunks/0-5de203df.js"),["chunks/0-5de203df.js","components/pages/_layout.svelte-646217a1.js","assets/app-9be9397c.css","chunks/index-af87de52.js","chunks/TypographyProvider.styles-82fbd465.js","assets/TypographyProvider-eca7ac57.css"],import.meta.url),()=>M(()=>import("./chunks/1-2631ecc1.js"),["chunks/1-2631ecc1.js","components/error.svelte-a00f4de2.js","chunks/index-af87de52.js","chunks/stores-5134a987.js","chunks/singletons-8c3bcd10.js","chunks/paths-846459bd.js"],import.meta.url),()=>M(()=>import("./chunks/2-7e9714cb.js"),["chunks/2-7e9714cb.js","components/pages/_version_/_error.svelte-38288245.js","assets/app-9be9397c.css","chunks/index-af87de52.js","chunks/stores-5134a987.js","chunks/singletons-8c3bcd10.js","chunks/paths-846459bd.js"],import.meta.url),()=>M(()=>import("./chunks/3-f8b29ee5.js"),["chunks/3-f8b29ee5.js","chunks/_page-11951769.js","chunks/api-184ef58a.js","chunks/control-6eaf9e57.js","chunks/paths-846459bd.js"],import.meta.url),()=>M(()=>import("./chunks/4-72a70dc8.js"),["chunks/4-72a70dc8.js","chunks/_page-63117c76.js","chunks/api-184ef58a.js","chunks/control-6eaf9e57.js","chunks/paths-846459bd.js"],import.meta.url),()=>M(()=>import("./chunks/5-5f2ab212.js"),["chunks/5-5f2ab212.js","chunks/_page-a6c13339.js","chunks/paths-846459bd.js","chunks/api-184ef58a.js","chunks/control-6eaf9e57.js","chunks/config-f7b121fb.js","assets/config-829b72cd.css","chunks/index-af87de52.js","chunks/TypographyProvider.styles-82fbd465.js","assets/TypographyProvider-eca7ac57.css","chunks/singletons-8c3bcd10.js","components/pages/_version_/_...documentId_.html/_page.svelte-7ce8df80.js","assets/_page-1d6f5b25.css"],import.meta.url)],jt=[],At={"":[3],"[version]":[4,[],[2]],"[version]/[...documentId].html":[5,[],[2]]},Pt={handleError:({error:r})=>{console.error(r)}},Nt="/__data.json";async function Ut(r){var e;for(const n in r)if(typeof((e=r[n])==null?void 0:e.then)=="function")return Object.fromEntries(await Promise.all(Object.entries(r).map(async([s,o])=>[s,await o])));return r}Object.getOwnPropertyNames(Object.prototype).sort().join("\0");Object.getOwnPropertyNames(Object.prototype).sort().join("\0");const Tt=-1,Dt=-2,Vt=-3,qt=-4,Ct=-5,Bt=-6;function Ft(r){const e=JSON.parse(r);if(typeof e=="number")return o(e);const n=e,s=Array(n.length);function o(l){if(l===Tt)return;if(l===Vt)return NaN;if(l===qt)return 1/0;if(l===Ct)return-1/0;if(l===Bt)return-0;if(l in s)return s[l];const t=n[l];if(!t||typeof t!="object")s[l]=t;else if(Array.isArray(t))if(typeof t[0]=="string")switch(t[0]){case"Date":s[l]=new Date(t[1]);break;case"Set":const h=new Set;s[l]=h;for(let y=1;y<t.length;y+=1)h.add(o(t[y]));break;case"Map":const d=new Map;s[l]=d;for(let y=1;y<t.length;y+=2)d.set(o(t[y]),o(t[y+1]));break;case"RegExp":s[l]=new RegExp(t[1],t[2]);break;case"Object":s[l]=Object(t[1]);break;case"BigInt":s[l]=BigInt(t[1]);break;case"null":const g=Object.create(null);s[l]=g;for(let y=1;y<t.length;y+=2)g[t[y]]=o(t[y+1]);break}else{const f=new Array(t.length);s[l]=f;for(let h=0;h<t.length;h+=1){const d=t[h];d!==Dt&&(f[h]=o(d))}}else{const f={};s[l]=f;for(const h in t){const d=t[h];f[h]=o(d)}}return s[l]}return o(0)}const Me="sveltekit:scroll",C="sveltekit:index",ae=bt(ue,jt,At,$t),ke=ue[0],Re=ue[1];ke();Re();let ee={};try{ee=JSON.parse(sessionStorage[Me])}catch{}function ye(r){ee[r]=ve()}function Jt({target:r,base:e,trailing_slash:n}){var De;const s=[];let o=null;const l={before_navigate:[],after_navigate:[]};let t={branch:[],error:null,url:null},f=!1,h=!1,d=!0,g=!1,y=!1,S,U=(De=history.state)==null?void 0:De[C];U||(U=Date.now(),history.replaceState({...history.state,[C]:U},"",location.href));const D=ee[U];D&&(history.scrollRestoration="manual",scrollTo(D.x,D.y));let V=!1,T,Oe,te;async function Ie(){te=te||Promise.resolve(),await te,te=null;const a=new URL(location.href),u=me(a,!0);o=null,await $e(u,a,[])}async function pe(a,{noscroll:u=!1,replaceState:p=!1,keepfocus:i=!1,state:c={}},m,_){return typeof a=="string"&&(a=new URL(a,Be(document))),_e({url:a,scroll:u?ve():null,keepfocus:i,redirect_chain:m,details:{state:c,replaceState:p},nav_token:_,accepted:()=>{},blocked:()=>{},type:"goto"})}async function Le(a){const u=me(a,!1);if(!u)throw new Error("Attempted to prefetch a URL that does not belong to this app");return o={id:u.id,promise:Pe(u)},o.promise}async function $e(a,u,p,i,c={},m){var k,E;Oe=c;let _=a&&await Pe(a);if(_||(_=await Te(u,null,x(new Error(`Not found: ${u.pathname}`),{url:u,params:{},routeId:null}),404)),u=(a==null?void 0:a.url)||u,Oe!==c)return!1;if(_.type==="redirect")if(p.length>10||p.includes(u.pathname))_=await ne({status:500,error:x(new Error("Redirect loop"),{url:u,params:{},routeId:null}),url:u,routeId:null});else return pe(new URL(_.location,u).href,{},[...p,u.pathname],c),!1;else((E=(k=_.props)==null?void 0:k.page)==null?void 0:E.status)>=400&&await K.updated.check()&&await re(u);if(s.length=0,y=!1,g=!0,i&&i.details){const{details:b}=i,v=b.replaceState?0:1;b.state[C]=U+=v,history[b.replaceState?"replaceState":"pushState"](b.state,"",u)}if(o=null,h){t=_.state,_.props.page&&(_.props.page.url=u);const b=se();S.$set(_.props),b()}else je(_);if(i){const{scroll:b,keepfocus:v}=i;if(!v){const O=document.body,L=O.getAttribute("tabindex");O.tabIndex=-1,O.focus({preventScroll:!0}),setTimeout(()=>{var $;($=getSelection())==null||$.removeAllRanges()}),L!==null?O.setAttribute("tabindex",L):O.removeAttribute("tabindex")}if(await Ce(),d){const O=u.hash&&document.getElementById(u.hash.slice(1));b?scrollTo(b.x,b.y):O?O.scrollIntoView():scrollTo(0,0)}}else await Ce();d=!0,_.props.page&&(T=_.props.page),m&&m(),g=!1}function je(a){var c,m;t=a.state;const u=document.querySelector("style[data-sveltekit]");u&&u.remove(),T=a.props.page;const p=se();S=new Ot({target:r,props:{...a.props,stores:K},hydrate:!0}),p();const i={from:null,to:oe("to",{params:t.params,routeId:(m=(c=t.route)==null?void 0:c.id)!=null?m:null,url:new URL(location.href)}),type:"load"};l.after_navigate.forEach(_=>_(i)),h=!0}async function Z({url:a,params:u,branch:p,status:i,error:c,route:m,form:_}){var L;const k=p.filter(Boolean),E={type:"loaded",state:{url:a,params:u,branch:p,error:c,route:m},props:{components:k.map($=>$.node.component)}};_!==void 0&&(E.props.form=_);let b={},v=!T;for(let $=0;$<k.length;$+=1){const P=k[$];b={...b,...P.data},(v||!t.branch.some(N=>N===P))&&(E.props[`data_${$}`]=b,v=v||Object.keys((L=P.data)!=null?L:{}).length>0)}if(v||(v=Object.keys(T.data).length!==Object.keys(b).length),!t.url||a.href!==t.url.href||t.error!==c||_!==void 0||v){E.props.page={error:c,params:u,routeId:m&&m.id,status:i,url:a,form:_,data:v?b:T.data};const $=(P,N)=>{Object.defineProperty(E.props.page,P,{get:()=>{throw new Error(`$page.${P} has been replaced by $page.url.${N}`)}})};$("origin","origin"),$("path","pathname"),$("query","searchParams")}return E}async function de({loader:a,parent:u,url:p,params:i,routeId:c,server_data_node:m}){var b,v,O,L,$;let _=null;const k={dependencies:new Set,params:new Set,parent:!1,url:!1},E=await a();if((b=E.shared)!=null&&b.load){let P=function(...I){for(const w of I){const{href:R}=new URL(w,p);k.dependencies.add(R)}};const N={routeId:c,params:new Proxy(i,{get:(I,w)=>(k.params.add(w),I[w])}),data:(v=m==null?void 0:m.data)!=null?v:null,url:ut(p,()=>{k.url=!0}),async fetch(I,w){let R;I instanceof Request?(R=I.url,w={body:I.method==="GET"||I.method==="HEAD"?void 0:await I.blob(),cache:I.cache,credentials:I.credentials,headers:I.headers,integrity:I.integrity,keepalive:I.keepalive,method:I.method,mode:I.mode,redirect:I.redirect,referrer:I.referrer,referrerPolicy:I.referrerPolicy,signal:I.signal,...w}):R=I;const A=new URL(R,p).href;return P(A),h?mt(A,w):ht(R,A,w)},setHeaders:()=>{},depends:P,parent(){return k.parent=!0,u()}};Object.defineProperties(N,{props:{get(){throw new Error("@migration task: Replace `props` with `data` stuff https://github.com/sveltejs/kit/discussions/5774#discussioncomment-3292693")},enumerable:!1},session:{get(){throw new Error("session is no longer available. See https://github.com/sveltejs/kit/discussions/5883")},enumerable:!1},stuff:{get(){throw new Error("@migration task: Remove stuff https://github.com/sveltejs/kit/discussions/5774#discussioncomment-3292693")},enumerable:!1}}),_=(O=await E.shared.load.call(null,N))!=null?O:null,_=_?await Ut(_):null}return{node:E,loader:a,server:m,shared:(L=E.shared)!=null&&L.load?{type:"data",data:_,uses:k}:null,data:($=_!=null?_:m==null?void 0:m.data)!=null?$:null}}function Ae(a,u,p,i){if(y)return!0;if(!p)return!1;if(p.parent&&u||p.url&&a)return!0;for(const c of p.params)if(i[c]!==t.params[c])return!0;for(const c of p.dependencies)if(s.some(m=>m(new URL(c))))return!0;return!1}function he(a,u){var p,i;return(a==null?void 0:a.type)==="data"?{type:"data",data:a.data,uses:{dependencies:new Set((p=a.uses.dependencies)!=null?p:[]),params:new Set((i=a.uses.params)!=null?i:[]),parent:!!a.uses.parent,url:!!a.uses.url}}:(a==null?void 0:a.type)==="skip"&&u!=null?u:null}async function Pe({id:a,invalidating:u,url:p,params:i,route:c}){var I;if((o==null?void 0:o.id)===a)return o.promise;const{errors:m,layouts:_,leaf:k}=c,E=[..._,k];m.forEach(w=>w==null?void 0:w().catch(()=>{})),E.forEach(w=>w==null?void 0:w[1]().catch(()=>{}));let b=null;const v=t.url?a!==t.url.pathname+t.url.search:!1,O=E.reduce((w,R,A)=>{var Q;const j=t.branch[A],H=!!(R!=null&&R[0])&&((j==null?void 0:j.loader)!==R[1]||Ae(v,w.some(Boolean),(Q=j.server)==null?void 0:Q.uses,i));return w.push(H),w},[]);if(O.some(Boolean)){try{b=await He(p,O)}catch(w){return ne({status:500,error:x(w,{url:p,params:i,routeId:c.id}),url:p,routeId:c.id})}if(b.type==="redirect")return b}const L=b==null?void 0:b.nodes;let $=!1;const P=E.map(async(w,R)=>{var Q;if(!w)return;const A=t.branch[R],j=L==null?void 0:L[R];if((!j||j.type==="skip")&&w[1]===(A==null?void 0:A.loader)&&!Ae(v,$,(Q=A.shared)==null?void 0:Q.uses,i))return A;if($=!0,(j==null?void 0:j.type)==="error")throw j;return de({loader:w[1],url:p,params:i,routeId:c.id,parent:async()=>{var qe;const Ve={};for(let ge=0;ge<R;ge+=1)Object.assign(Ve,(qe=await P[ge])==null?void 0:qe.data);return Ve},server_data_node:he(j===void 0&&w[0]?{type:"skip"}:j!=null?j:null,A==null?void 0:A.server)})});for(const w of P)w.catch(()=>{});const N=[];for(let w=0;w<E.length;w+=1)if(E[w])try{N.push(await P[w])}catch(R){if(R instanceof Je)return{type:"redirect",location:R.location};let A=500,j;L!=null&&L.includes(R)?(A=(I=R.status)!=null?I:A,j=R.error):R instanceof Ee?(A=R.status,j=R.body):j=x(R,{params:i,url:p,routeId:c.id});const H=await Ne(w,N,m);return H?await Z({url:p,params:i,branch:N.slice(0,H.idx).concat(H.node),status:A,error:j,route:c}):await Te(p,c.id,j,A)}else N.push(void 0);return await Z({url:p,params:i,branch:N,status:200,error:null,route:c,form:u?void 0:null})}async function Ne(a,u,p){for(;a--;)if(p[a]){let i=a;for(;!u[i];)i-=1;try{return{idx:i+1,node:{node:await p[a](),loader:p[a],data:{},server:null,shared:null}}}catch{continue}}}async function ne({status:a,error:u,url:p,routeId:i}){var b;const c={},m=await ke();let _=null;if(m.server)try{const v=await He(p,[!0]);if(v.type!=="data"||v.nodes[0]&&v.nodes[0].type!=="data")throw 0;_=(b=v.nodes[0])!=null?b:null}catch{(p.origin!==location.origin||p.pathname!==location.pathname||f)&&await re(p)}const k=await de({loader:ke,url:p,params:c,routeId:i,parent:()=>Promise.resolve({}),server_data_node:he(_)}),E={node:await Re(),loader:Re,shared:null,server:null,data:null};return await Z({url:p,params:c,branch:[k,E],status:a,error:u,route:null})}function me(a,u){if(Ue(a))return;const p=decodeURI(a.pathname.slice(e.length)||"/");for(const i of ae){const c=i.exec(p);if(c){const m=new URL(a.origin+lt(a.pathname,n)+a.search+a.hash);return{id:m.pathname+m.search,invalidating:u,route:i,params:ct(c),url:m}}}}function Ue(a){return a.origin!==location.origin||!a.pathname.startsWith(e)}async function _e({url:a,scroll:u,keepfocus:p,redirect_chain:i,details:c,type:m,delta:_,nav_token:k,accepted:E,blocked:b}){var P,N,I,w;let v=!1;const O=me(a,!1),L={from:oe("from",{params:t.params,routeId:(N=(P=t.route)==null?void 0:P.id)!=null?N:null,url:t.url}),to:oe("to",{params:(I=O==null?void 0:O.params)!=null?I:null,routeId:(w=O==null?void 0:O.route.id)!=null?w:null,url:a}),type:m};_!==void 0&&(L.delta=_);const $={...L,cancel:()=>{v=!0}};if(l.before_navigate.forEach(R=>R($)),v){b();return}ye(U),E(),h&&K.navigating.set(L),await $e(O,a,i,{scroll:u,keepfocus:p,details:c},k,()=>{l.after_navigate.forEach(R=>R(L)),K.navigating.set(null)})}async function Te(a,u,p,i){return a.origin===location.origin&&a.pathname===location.pathname&&!f?await ne({status:i,error:p,url:a,routeId:u}):await re(a)}function re(a){return location.href=a.href,new Promise(()=>{})}return{after_navigate:a=>{be(()=>(l.after_navigate.push(a),()=>{const u=l.after_navigate.indexOf(a);l.after_navigate.splice(u,1)}))},before_navigate:a=>{be(()=>(l.before_navigate.push(a),()=>{const u=l.before_navigate.indexOf(a);l.before_navigate.splice(u,1)}))},disable_scroll_handling:()=>{(g||!h)&&(d=!1)},goto:(a,u={})=>pe(a,u,[]),invalidate:a=>{if(a===void 0)throw new Error("`invalidate()` (with no arguments) has been replaced by `invalidateAll()`");if(typeof a=="function")s.push(a);else{const{href:u}=new URL(a,location.href);s.push(p=>p.href===u)}return Ie()},invalidateAll:()=>(y=!0,Ie()),prefetch:async a=>{const u=new URL(a,Be(document));await Le(u)},prefetch_routes:async a=>{const p=(a?ae.filter(i=>a.some(c=>i.exec(c))):ae).map(i=>Promise.all([...i.layouts,i.leaf].map(c=>c==null?void 0:c[1]())));await Promise.all(p)},apply_action:async a=>{if(a.type==="error"){const u=new URL(location.href),{branch:p,route:i}=t;if(!i)return;const c=await Ne(t.branch.length,p,i.errors);if(c){const m=await Z({url:u,params:t.params,branch:p.slice(0,c.idx).concat(c.node),status:500,error:a.error,route:i});t=m.state;const _=se();S.$set(m.props),_()}}else if(a.type==="redirect")pe(a.location,{},[]);else{const u={form:a.data,page:{...T,form:a.data,status:a.status}},p=se();S.$set(u),p()}},_start_router:()=>{history.scrollRestoration="manual",addEventListener("beforeunload",i=>{var _,k;let c=!1;const m={from:oe("from",{params:t.params,routeId:(k=(_=t.route)==null?void 0:_.id)!=null?k:null,url:t.url}),to:null,type:"unload",cancel:()=>c=!0};l.before_navigate.forEach(E=>E(m)),c?(i.preventDefault(),i.returnValue=""):history.scrollRestoration="auto"}),addEventListener("visibilitychange",()=>{if(document.visibilityState==="hidden"){ye(U);try{sessionStorage[Me]=JSON.stringify(ee)}catch{}}});const a=i=>{const{url:c,options:m}=Fe(i);if(c&&m.prefetch){if(Ue(c))return;Le(c)}};let u;const p=i=>{clearTimeout(u),u=setTimeout(()=>{var c;(c=i.target)==null||c.dispatchEvent(new CustomEvent("sveltekit:trigger_prefetch",{bubbles:!0}))},20)};addEventListener("touchstart",a),addEventListener("mousemove",p),addEventListener("sveltekit:trigger_prefetch",a),addEventListener("click",i=>{if(i.button||i.which!==1||i.metaKey||i.ctrlKey||i.shiftKey||i.altKey||i.defaultPrevented)return;const{a:c,url:m,options:_}=Fe(i);if(!c||!m)return;const k=c instanceof SVGAElement;if(!k&&m.protocol!==location.protocol&&!(m.protocol==="https:"||m.protocol==="http:"))return;const E=(c.getAttribute("rel")||"").split(/\s+/);if(c.hasAttribute("download")||E.includes("external")||_.reload||(k?c.target.baseVal:c.target))return;const[b,v]=m.href.split("#");if(v!==void 0&&b===location.href.split("#")[0]){V=!0,ye(U),t.url=m,K.page.set({...T,url:m}),K.page.notify();return}_e({url:m,scroll:_.noscroll?ve():null,keepfocus:!1,redirect_chain:[],details:{state:{},replaceState:m.href===location.href},accepted:()=>i.preventDefault(),blocked:()=>i.preventDefault(),type:"link"})}),addEventListener("popstate",i=>{if(i.state){if(i.state[C]===U)return;const c=i.state[C]-U;_e({url:new URL(location.href),scroll:ee[i.state[C]],keepfocus:!1,redirect_chain:[],details:null,accepted:()=>{U=i.state[C]},blocked:()=>{history.go(-c)},type:"popstate",delta:c})}}),addEventListener("hashchange",()=>{V&&(V=!1,history.replaceState({...history.state,[C]:++U},"",location.href))});for(const i of document.querySelectorAll("link"))i.rel==="icon"&&(i.href=i.href);addEventListener("pageshow",i=>{i.persisted&&K.navigating.set(null)})},_hydrate:async({status:a,error:u,node_ids:p,params:i,routeId:c,data:m,form:_})=>{var b;f=!0;const k=new URL(location.href);let E;try{const v=p.map(async(O,L)=>{const $=m[L];return de({loader:ue[O],url:k,params:i,routeId:c,parent:async()=>{const P={};for(let N=0;N<L;N+=1)Object.assign(P,(await v[N]).data);return P},server_data_node:he($)})});E=await Z({url:k,params:i,branch:await Promise.all(v),status:a,error:u,form:_,route:(b=ae.find(O=>O.id===c))!=null?b:null})}catch(v){if(v instanceof Je){await re(new URL(v.location,location.href));return}E=await ne({status:v instanceof Ee?v.status:500,error:x(v,{url:k,params:i,routeId:c}),url:k,routeId:c})}je(E)}}}async function He(r,e){const n=new URL(r);n.pathname=r.pathname.replace(/\/$/,"")+Nt;const s=await fe(n.href,{headers:{"x-sveltekit-invalidated":e.map(l=>l?"1":"").join(",")}}),o=await s.text();if(!s.ok)throw new Error(JSON.parse(o));return Ft(o)}function x(r,e){var n;return r instanceof Ee?r.body:(n=Pt.handleError({error:r,event:e}))!=null?n:{message:e.routeId!=null?"Internal Error":"Not Found"}}const Gt=["hash","href","host","hostname","origin","pathname","port","protocol","search","searchParams","toString","toJSON"];function oe(r,e){for(const n of Gt)Object.defineProperty(e,n,{get(){throw new Error(`The navigation shape changed - ${r}.${n} should now be ${r}.url.${n}`)},enumerable:!1});return e}function se(){return()=>{}}async function Wt({env:r,hydrate:e,paths:n,target:s,trailing_slash:o}){it(n);const l=Jt({target:s,base:n.base,trailing_slash:o});st({client:l}),e?await l._hydrate(e):l.goto(location.href,{replaceState:!0}),l._start_router()}export{Wt as start};
