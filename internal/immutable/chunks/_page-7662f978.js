import{b as d}from"./paths-846459bd.js";import{t as a,A as P}from"./api-41b79f33.js";import{S as _}from"./config-5cfdf316.js";const I=!0,w=!0,D=async({params:i,fetch:l,url:m})=>{const{version:o,documentId:s}=i;console.log(`Prerendering ${s}`);const r=`${d}/data`,e=new P(r,o,l),n=await e.loadVersions();a(n);const c=await e.loadDocumentIndex(o);a(c);const u=n[o];let t=s==""?[u.defaultDocument]:[s];t=[t[0],...m.searchParams.getAll("id")];const p=await e.loadDocuments(t.filter(b=>!Object.keys(_).includes(b)));a(p[0]);const{documents:f,docversions:g,pkgindexes:A}=e;return{apiData:{documents:f,docversions:g,pkgindexes:A},documentIds:t,docindex:c,version:o,versions:n,dataUrl:r,baseUrl:`${d}/${o}`}},y=Object.freeze(Object.defineProperty({__proto__:null,csr:I,prerender:w,load:D},Symbol.toStringTag,{value:"Module"}));export{y as _,I as c,D as l,w as p};
