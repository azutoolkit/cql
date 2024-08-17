import{_ as l,o as s,c as n,x as e,a}from"./app.b139ab4d.js";import"./chunks/theme.1ff6d68a.js";const _=JSON.parse('{"title":"Cql::Relations::HasMany","description":"","frontmatter":{"title":"Cql::Relations::HasMany"},"headers":[{"level":2,"title":"Macros","slug":"macros","link":"#macros","children":[{"level":3,"title":"macro has_many(name, type, foreign_key, cascade = false)","slug":"macro-has-many-name-type-foreign-key-cascade-false","link":"#macro-has-many-name-type-foreign-key-cascade-false","children":[]}]}],"relativePath":"main/Cql/Relations/HasMany.md","lastUpdated":1723931959000}'),o={name:"main/Cql/Relations/HasMany.md"},t=e("div",null,[e("h1",{id:"module-cql-relations-hasmany",tabindex:"-1"},[a("module Cql::Relations::HasMany "),e("a",{class:"header-anchor",href:"#module-cql-relations-hasmany","aria-hidden":"true"},"#")]),e("p",null,"Define the has_many association module that will be included in the model to define a one-to-many relationship between two tables in the database and provide methods to manage the association between the two tables and query records in the associated table based on the foreign key value of the parent record."),e("ul",null,[e("li",null,[e("strong",null,"param"),a(" : name (Symbol) - The name of the association")]),e("li",null,[e("strong",null,"param"),a(" : type (Cql::Model) - The target model")]),e("li",null,[e("strong",null,"param"),a(" : foreign_key (Symbol) - The foreign key column in the target table")]),e("li",null,[e("strong",null,"return"),a(" : Nil")])]),e("p",null,[e("strong",null,"Example")]),e("div",{class:"language-crystal"},[e("button",{title:"Copy Code",class:"copy"}),e("span",{class:"lang"},"crystal"),e("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[e("code",null,[e("span",{class:"line"},[e("span",{style:{color:"#89DDFF","font-style":"italic"}},"class"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"User")]),a(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  "),e("span",{style:{color:"#89DDFF","font-style":"italic"}},"include"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Cql"),e("span",{style:{color:"#89DDFF"}},"::"),e("span",{style:{color:"#FFCB6B"}},"Model"),e("span",{style:{color:"#89DDFF"}},"("),e("span",{style:{color:"#FFCB6B"}},"User"),e("span",{style:{color:"#89DDFF"}},","),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Int64"),e("span",{style:{color:"#89DDFF"}},")")]),a(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  "),e("span",{style:{color:"#82AAFF"}},"property"),e("span",{style:{color:"#BABED8"}}," id "),e("span",{style:{color:"#89DDFF"}},":"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Int64")]),a(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  "),e("span",{style:{color:"#82AAFF"}},"property"),e("span",{style:{color:"#BABED8"}}," name "),e("span",{style:{color:"#89DDFF"}},":"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"String")]),a(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"  has_many "),e("span",{style:{color:"#89DDFF"}},":posts,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"Post"),e("span",{style:{color:"#89DDFF"}},","),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},"foreign_key:"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},":user_id")]),a(`
`),e("span",{class:"line"},[e("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),a(`
`),e("span",{class:"line"})])])]),e("details",{class:"details custom-block"},[e("summary",null,"Table of Contents"),e("nav",{class:"table-of-contents"},[e("ul",null,[e("li",null,[e("a",{href:"#macros"},"Macros"),e("ul",null,[e("li",null,[e("a",{href:"#macro-has-many-name-type-foreign-key-cascade-false"},"macro has_many(name, type, foreign_key, cascade = false)")])])])])])])],-1),r=e("h2",{id:"macros",tabindex:"-1"},[a("Macros "),e("a",{class:"header-anchor",href:"#macros","aria-hidden":"true"},"#")],-1),c=e("h3",{id:"macro-has-many-name-type-foreign-key-cascade-false",tabindex:"-1"},[a("macro has_many"),e("code",null,"(name, type, foreign_key, cascade = false)"),a(),e("a",{class:"header-anchor",href:"#macro-has-many-name-type-foreign-key-cascade-false","aria-hidden":"true"},"#")],-1),i=e("p",null,":::",-1),y=[t,r,c,i];function p(d,m,h,u,B,F){return s(),n("div",null,y)}const g=l(o,[["render",p]]);export{_ as __pageData,g as default};
