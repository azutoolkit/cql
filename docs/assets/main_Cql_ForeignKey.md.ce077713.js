import{_ as l,o as n,c as o,x as e,a as s}from"./app.b139ab4d.js";import"./chunks/theme.1ff6d68a.js";const g=JSON.parse('{"title":"Cql::ForeignKey","description":"","frontmatter":{"title":"Cql::ForeignKey"},"headers":[{"level":2,"title":"Constructors","slug":"constructors","link":"#constructors","children":[{"level":3,"title":"def new(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = \\"NO ACTION\\", on_update : String = \\"NO ACTION\\")","slug":"def-new-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action","link":"#def-new-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action","children":[]}]}],"relativePath":"main/Cql/ForeignKey.md","lastUpdated":1723931959000}'),a={name:"main/Cql/ForeignKey.md"},t=e("div",null,[e("h1",{id:"class-cql-foreignkey",tabindex:"-1"},[s("class Cql::ForeignKey "),e("a",{class:"header-anchor",href:"#class-cql-foreignkey","aria-hidden":"true"},"#")]),e("p",null,[e("code",null,"Reference"),s(" < "),e("code",null,"Object")]),e("p",null,"A foreign key constraint This class represents a foreign key constraint It provides methods for setting the columns, table, and references It also provides methods for setting the on delete and on update actions"),e("p",null,[e("strong",null,"Example"),s(" Creating a new foreign key")]),e("div",{class:"language-crystal"},[e("button",{title:"Copy Code",class:"copy"}),e("span",{class:"lang"},"crystal"),e("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[e("code",null,[e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"schema"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#BABED8"}},"build "),e("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  table "),e("span",{style:{color:"#89DDFF"}},":users"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"    column "),e("span",{style:{color:"#89DDFF"}},":id,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Int32"),e("span",{style:{color:"#89DDFF"}},","),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},"primary:"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FF9CAC"}},"true")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"    column "),e("span",{style:{color:"#89DDFF"}},":name,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"String")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  "),e("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),e("span",{class:"line"}),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"table "),e("span",{style:{color:"#89DDFF"}},":posts"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  column "),e("span",{style:{color:"#89DDFF"}},":id,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Int32"),e("span",{style:{color:"#89DDFF"}},","),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},"primary:"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FF9CAC"}},"true")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  column "),e("span",{style:{color:"#89DDFF"}},":user_id,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Int32")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  foreign_key "),e("span",{style:{color:"#89DDFF"}},"[:user_id],"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},":users,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},"[:id]")]),s(`
`),e("span",{class:"line"},[e("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),e("span",{class:"line"})])])]),e("details",{class:"details custom-block"},[e("summary",null,"Table of Contents"),e("nav",{class:"table-of-contents"},[e("ul",null,[e("li",null,[e("a",{href:"#constructors"},"Constructors"),e("ul",null,[e("li",null,[e("a",{href:"#def-new-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action"},'def new(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = "NO ACTION", on_update : String = "NO ACTION")')])])])])])])],-1),r=e("h2",{id:"constructors",tabindex:"-1"},[s("Constructors "),e("a",{class:"header-anchor",href:"#constructors","aria-hidden":"true"},"#")],-1),c=e("h3",{id:"def-new-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action",tabindex:"-1"},[s("def new"),e("code",null,'(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = "NO ACTION", on_update : String = "NO ACTION")'),s(),e("a",{class:"header-anchor",href:"#def-new-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action","aria-hidden":"true"},"#")],-1),i=e("p",null,":::",-1),y=[t,r,c,i];function p(d,m,u,D,F,B){return n(),o("div",null,y)}const A=l(a,[["render",p]]);export{g as __pageData,A as default};
