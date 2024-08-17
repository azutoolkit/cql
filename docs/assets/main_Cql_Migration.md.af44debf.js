import{_ as a,o as e,c as n,x as l,a as s,N as o}from"./app.b139ab4d.js";import"./chunks/theme.1ff6d68a.js";const g=JSON.parse('{"title":"Cql::Migration","description":"","frontmatter":{"title":"Cql::Migration"},"headers":[{"level":2,"title":"Constructors","slug":"constructors","link":"#constructors","children":[{"level":3,"title":"def new(schema : Schema)","slug":"def-new-schema-schema","link":"#def-new-schema-schema","children":[]}]},{"level":2,"title":"Instance Methods","slug":"instance-methods","link":"#instance-methods","children":[{"level":3,"title":"def down","slug":"def-down","link":"#def-down","children":[]},{"level":3,"title":"def schema","slug":"def-schema","link":"#def-schema","children":[]},{"level":3,"title":"def up","slug":"def-up","link":"#def-up","children":[]}]}],"relativePath":"main/Cql/Migration.md","lastUpdated":1723931959000}'),t={name:"main/Cql/Migration.md"},c=l("div",null,[l("h1",{id:"class-cql-migration",tabindex:"-1"},[s("class Cql::Migration "),l("a",{class:"header-anchor",href:"#class-cql-migration","aria-hidden":"true"},"#")]),l("p",null,[l("code",null,"Reference"),s(" < "),l("code",null,"Object")]),l("p",null,[s("Migrations are used to manage changes to the database schema over time. Each migration is a subclass of "),l("code",null,"Migration"),s(" and must implement the "),l("code",null,"up"),s(" and "),l("code",null,"down"),s(" methods.")]),l("p",null,[s("The "),l("code",null,"up"),s(" method is used to apply the migration, while the "),l("code",null,"down"),s(" method is used to rollback the migration. Migrations are executed in their version order defined. The "),l("code",null,"Migrator"),s(" class is used to manage migrations and provides methods to apply, rollback, and redo migrations. The "),l("code",null,"Migrator"),s(" class also provides methods to list applied and pending migrations.")]),l("p",null,[l("strong",null,"Example"),s(" Creating a new migration")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#89DDFF","font-style":"italic"}},"class"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"CreateUsersTable "),l("span",{style:{color:"#89DDFF"}},"<"),l("span",{style:{color:"#FFCB6B"}}," Cql::Migration")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  self"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"version "),l("span",{style:{color:"#89DDFF"}},"="),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#F78C6C"}},"1_i64")]),s(`
`),l("span",{class:"line"}),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"def"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#82AAFF"}},"up")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    schema"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"alter "),l("span",{style:{color:"#89DDFF"}},":users"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"      add_column "),l("span",{style:{color:"#89DDFF"}},":name,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"String")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"      add_column "),l("span",{style:{color:"#89DDFF"}},":age,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"Int32")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"}),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"def"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#82AAFF"}},"down")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    schema"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"alter "),l("span",{style:{color:"#89DDFF"}},":users"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"      drop_column "),l("span",{style:{color:"#89DDFF"}},":name")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"      drop_column "),l("span",{style:{color:"#89DDFF"}},":age")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Applying migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"schema "),l("span",{style:{color:"#89DDFF"}},"="),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"Cql"),l("span",{style:{color:"#89DDFF"}},"::"),l("span",{style:{color:"#FFCB6B"}},"Schema"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#82AAFF"}},"build"),l("span",{style:{color:"#89DDFF"}},"(:northwind,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF"}},'"'),l("span",{style:{color:"#C3E88D"}},"sqlite3://db.sqlite3"),l("span",{style:{color:"#89DDFF"}},'"'),l("span",{style:{color:"#89DDFF"}},")"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"do "),l("span",{style:{color:"#89DDFF"}},"|"),l("span",{style:{color:"#BABED8"}},"s"),l("span",{style:{color:"#89DDFF"}},"|")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  table "),l("span",{style:{color:"#89DDFF"}},":schema_migrations"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"do")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    primary "),l("span",{style:{color:"#89DDFF"}},":id,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"Int32")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    column "),l("span",{style:{color:"#89DDFF"}},":name,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"String")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    column "),l("span",{style:{color:"#89DDFF"}},":version,"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"Int64"),l("span",{style:{color:"#89DDFF"}},","),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF"}},"index:"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FF9CAC"}},"true"),l("span",{style:{color:"#89DDFF"}},","),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#89DDFF"}},"unique:"),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FF9CAC"}},"true")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"    timestamps")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"  "),l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#89DDFF","font-style":"italic"}},"end")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator "),l("span",{style:{color:"#89DDFF"}},"="),l("span",{style:{color:"#BABED8"}}," "),l("span",{style:{color:"#FFCB6B"}},"Cql"),l("span",{style:{color:"#89DDFF"}},"::"),l("span",{style:{color:"#FFCB6B"}},"Migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#82AAFF"}},"new"),l("span",{style:{color:"#89DDFF"}},"("),l("span",{style:{color:"#BABED8"}},"schema"),l("span",{style:{color:"#89DDFF"}},")")]),s(`
`),l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"up")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Rolling back migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"down")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Redoing migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"redo")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Rolling back to a specific version")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#82AAFF"}},"down_to"),l("span",{style:{color:"#89DDFF"}},"("),l("span",{style:{color:"#F78C6C"}},"1_i64"),l("span",{style:{color:"#89DDFF"}},")")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Applying to a specific version")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#82AAFF"}},"up_to"),l("span",{style:{color:"#89DDFF"}},"("),l("span",{style:{color:"#F78C6C"}},"1_i64"),l("span",{style:{color:"#89DDFF"}},")")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Listing applied migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"print_applied_migrations")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Listing pending migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"print_pending_migrations")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Listing rolled back migrations")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"print_rolled_back_migrations")]),s(`
`),l("span",{class:"line"})])])]),l("p",null,[l("strong",null,"Example"),s(" Listing the last migration")]),l("div",{class:"language-crystal"},[l("button",{title:"Copy Code",class:"copy"}),l("span",{class:"lang"},"crystal"),l("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[l("code",null,[l("span",{class:"line"},[l("span",{style:{color:"#BABED8"}},"migrator"),l("span",{style:{color:"#89DDFF"}},"."),l("span",{style:{color:"#BABED8"}},"last")]),s(`
`),l("span",{class:"line"})])])]),l("details",{class:"details custom-block"},[l("summary",null,"Table of Contents"),l("nav",{class:"table-of-contents"},[l("ul",null,[l("li",null,[l("a",{href:"#constructors"},"Constructors"),l("ul",null,[l("li",null,[l("a",{href:"#def-new-schema-schema"},"def new(schema : Schema)")])])]),l("li",null,[l("a",{href:"#instance-methods"},"Instance Methods"),l("ul",null,[l("li",null,[l("a",{href:"#def-down"},"def down")]),l("li",null,[l("a",{href:"#def-schema"},"def schema")]),l("li",null,[l("a",{href:"#def-up"},"def up")])])])])])])],-1),r=o('<h2 id="constructors" tabindex="-1">Constructors <a class="header-anchor" href="#constructors" aria-hidden="true">#</a></h2><h3 id="def-new-schema-schema" tabindex="-1">def new<code>(schema : Schema)</code> <a class="header-anchor" href="#def-new-schema-schema" aria-hidden="true">#</a></h3><h2 id="instance-methods" tabindex="-1">Instance Methods <a class="header-anchor" href="#instance-methods" aria-hidden="true">#</a></h2><h3 id="def-down" tabindex="-1">def down <a class="header-anchor" href="#def-down" aria-hidden="true">#</a></h3><h3 id="def-schema" tabindex="-1">def schema <a class="header-anchor" href="#def-schema" aria-hidden="true">#</a></h3><h3 id="def-up" tabindex="-1">def up <a class="header-anchor" href="#def-up" aria-hidden="true">#</a></h3><p>:::</p>',7),i=[c,r];function p(d,y,D,F,B,h){return e(),n("div",null,i)}const A=a(t,[["render",p]]);export{g as __pageData,A as default};
