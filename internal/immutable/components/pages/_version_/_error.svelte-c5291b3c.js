import{S as L,i as Q,s as U,k as v,q as p,a as M,l as m,m as g,r as _,h as a,c as T,n as I,b as S,F as l,u as W,X as V,O as Y,e as z,af as Z}from"../../../chunks/index-af87de52.js";import{p as ee}from"../../../chunks/stores-16012a17.js";/* empty css                          */import{b as te}from"../../../chunks/paths-846459bd.js";function B(i,e,t){const s=i.slice();return s[2]=e[t],s}function re(i){let e;return{c(){e=p("Missing error message :(")},l(t){e=_(t,"Missing error message :(")},m(t,s){S(t,e,s)},p:V,d(t){t&&a(e)}}}function se(i){let e,t,s,n=i[1].document+"",d;return{c(){e=v("p"),t=p("Could not find page with ID "),s=v("code"),d=p(n)},l(f){e=m(f,"P",{});var u=g(e);t=_(u,"Could not find page with ID "),s=m(u,"CODE",{});var k=g(s);d=_(k,n),k.forEach(a),u.forEach(a)},m(f,u){S(f,e,u),l(e,t),l(e,s),l(s,d)},p:V,d(f){f&&a(e)}}}function le(i){let e,t,s,n=i[1].version+"",d,f,u,k,P,y,b=i[1].versions,c=[];for(let r=0;r<b.length;r+=1)c[r]=G(B(i,b,r));return{c(){e=v("p"),t=p("Tried to access a version of the site that does not exist: "),s=v("code"),d=p(n),f=M(),u=v("p"),k=p("Please access one of the valid versions:"),P=M();for(let r=0;r<c.length;r+=1)c[r].c();y=z()},l(r){e=m(r,"P",{});var h=g(e);t=_(h,"Tried to access a version of the site that does not exist: "),s=m(h,"CODE",{});var o=g(s);d=_(o,n),o.forEach(a),h.forEach(a),f=T(r),u=m(r,"P",{});var E=g(u);k=_(E,"Please access one of the valid versions:"),E.forEach(a),P=T(r);for(let w=0;w<c.length;w+=1)c[w].l(r);y=z()},m(r,h){S(r,e,h),l(e,t),l(e,s),l(s,d),S(r,f,h),S(r,u,h),l(u,k),S(r,P,h);for(let o=0;o<c.length;o+=1)c[o].m(r,h);S(r,y,h)},p(r,h){if(h&2){b=r[1].versions;let o;for(o=0;o<b.length;o+=1){const E=B(r,b,o);c[o]?c[o].p(E,h):(c[o]=G(E),c[o].c(),c[o].m(y.parentNode,y))}for(;o<c.length;o+=1)c[o].d(1);c.length=b.length}},d(r){r&&a(e),r&&a(f),r&&a(u),r&&a(P),Z(c,r),r&&a(y)}}}function oe(i){let e,t,s,n,d,f=i[1].host+"",u,k,P=i[1].port+"",y,b,c,r,h;return{c(){e=v("p"),t=p("The Pollen.jl development server was not found running at the expected address: "),s=v("a"),n=v("code"),d=p("http://"),u=p(f),k=p(":"),y=p(P),b=p(". Make sure you have started it using "),c=v("code"),r=p("Pollen.serve"),h=p("."),this.h()},l(o){e=m(o,"P",{});var E=g(e);t=_(E,"The Pollen.jl development server was not found running at the expected address: "),s=m(E,"A",{href:!0,target:!0});var w=g(s);n=m(w,"CODE",{class:!0});var D=g(n);d=_(D,"http://"),u=_(D,f),k=_(D,":"),y=_(D,P),D.forEach(a),w.forEach(a),b=_(E,". Make sure you have started it using "),c=m(E,"CODE",{});var x=g(c);r=_(x,"Pollen.serve"),x.forEach(a),h=_(E,"."),E.forEach(a),this.h()},h(){I(n,"class","text-base text-bluegray-600 bg-gray-50"),I(s,"href","http://"+i[1].host+":"+i[1].port),I(s,"target","_blank")},m(o,E){S(o,e,E),l(e,t),l(e,s),l(s,n),l(n,d),l(n,u),l(n,k),l(n,y),l(e,b),l(e,c),l(c,r),l(e,h)},p:V,d(o){o&&a(e)}}}function G(i){let e,t=i[2]+"",s;return{c(){e=v("a"),s=p(t),this.h()},l(n){e=m(n,"A",{class:!0,href:!0});var d=g(e);s=_(d,t),d.forEach(a),this.h()},h(){I(e,"class","reference"),I(e,"href",te+"/"+i[2])},m(n,d){S(n,e,d),l(e,s)},p:V,d(n){n&&a(e)}}}function ae(i){let e,t,s,n,d,f,u,k=i[0].status+"",P,y,b,c,r,h,o,E,w,D,x,q=JSON.stringify(i[1],null,"	")+"",$;function K(C,A){return C[1].type=="devserverunavailable"?oe:C[1].type=="invalidversion"?le:C[1].type=="docnotfound"?se:re}let N=K(i)(i);return{c(){e=v("div"),t=v("div"),s=v("h1"),n=p("An error occured!"),d=M(),f=v("div"),u=p("Status code: "),P=p(k),y=M(),b=v("div"),N.c(),c=M(),r=v("hr"),h=M(),o=v("p"),E=p("Complete error information:"),w=M(),D=v("pre"),x=v("code"),$=p(q),this.h()},l(C){e=m(C,"DIV",{class:!0});var A=g(e);t=m(A,"DIV",{class:!0});var O=g(t);s=m(O,"H1",{});var H=g(s);n=_(H,"An error occured!"),H.forEach(a),d=T(O),f=m(O,"DIV",{class:!0});var j=g(f);u=_(j,"Status code: "),P=_(j,k),j.forEach(a),y=T(O),b=m(O,"DIV",{class:!0});var J=g(b);N.l(J),J.forEach(a),c=T(O),r=m(O,"HR",{}),h=T(O),o=m(O,"P",{});var R=g(o);E=_(R,"Complete error information:"),R.forEach(a),w=T(O),D=m(O,"PRE",{class:!0});var F=g(D);x=m(F,"CODE",{});var X=g(x);$=_(X,q),X.forEach(a),F.forEach(a),O.forEach(a),A.forEach(a),this.h()},h(){I(f,"class","subtitle"),I(b,"class","errormessage text-lg"),I(D,"class","codeblock"),I(t,"class","markdown"),I(e,"class","container m-4 lg:mt-8 lg:max-w-2xl mx-auto")},m(C,A){S(C,e,A),l(e,t),l(t,s),l(s,n),l(t,d),l(t,f),l(f,u),l(f,P),l(t,y),l(t,b),N.m(b,null),l(t,c),l(t,r),l(t,h),l(t,o),l(o,E),l(t,w),l(t,D),l(D,x),l(x,$)},p(C,[A]){A&1&&k!==(k=C[0].status+"")&&W(P,k),N.p(C,A)},i:V,o:V,d(C){C&&a(e),N.d()}}}function ne(i,e,t){let s;Y(i,ee,d=>t(0,s=d));const n=JSON.parse(s.error.message).message;return[s,n]}class ue extends L{constructor(e){super(),Q(this,e,ne,ae,U,{})}}export{ue as default};
