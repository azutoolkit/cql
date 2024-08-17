import{_ as n,o as a,c as s,x as e,a as l,N as o}from"./app.b139ab4d.js";import"./chunks/theme.1ff6d68a.js";const D=JSON.parse('{"title":"Cql::AlterTable","description":"","frontmatter":{"title":"Cql::AlterTable"},"headers":[{"level":2,"title":"Constructors","slug":"constructors","link":"#constructors","children":[{"level":3,"title":"def new(table : Cql::Table, schema : Cql::Schema)","slug":"def-new-table-cql-table-schema-cql-schema","link":"#def-new-table-cql-table-schema-cql-schema","children":[]}]},{"level":2,"title":"Instance Methods","slug":"instance-methods","link":"#instance-methods","children":[{"level":3,"title":"def add_column(name : Symbol, type : Any, as as_name : String | Nil = nil, null : Bool = true, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)","slug":"def-add-column-name-symbol-type-any-as-as-name-string-nil-nil-null-bool-true-default-db-any-nil-unique-bool-false-size-int32-nil-nil-index-bool-false","link":"#def-add-column-name-symbol-type-any-as-as-name-string-nil-nil-null-bool-true-default-db-any-nil-unique-bool-false-size-int32-nil-nil-index-bool-false","children":[]},{"level":3,"title":"def change_column(name : Symbol, type : Any)","slug":"def-change-column-name-symbol-type-any","link":"#def-change-column-name-symbol-type-any","children":[]},{"level":3,"title":"def create_index(name : Symbol, columns : Array(Symbol), unique : Bool = false)","slug":"def-create-index-name-symbol-columns-array-symbol-unique-bool-false","link":"#def-create-index-name-symbol-columns-array-symbol-unique-bool-false","children":[]},{"level":3,"title":"def drop_column(column : Symbol)","slug":"def-drop-column-column-symbol","link":"#def-drop-column-column-symbol","children":[]},{"level":3,"title":"def drop_foreign_key(name : Symbol)","slug":"def-drop-foreign-key-name-symbol","link":"#def-drop-foreign-key-name-symbol","children":[]},{"level":3,"title":"def drop_index(name : Symbol)","slug":"def-drop-index-name-symbol","link":"#def-drop-index-name-symbol","children":[]},{"level":3,"title":"def foreign_key(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = \\"NO ACTION\\", on_update : String = \\"NO ACTION\\")","slug":"def-foreign-key-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action","link":"#def-foreign-key-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action","children":[]},{"level":3,"title":"def rename_column(old_name : Symbol, new_name : Symbol)","slug":"def-rename-column-old-name-symbol-new-name-symbol","link":"#def-rename-column-old-name-symbol-new-name-symbol","children":[]},{"level":3,"title":"def rename_table(new_name : Symbol)","slug":"def-rename-table-new-name-symbol","link":"#def-rename-table-new-name-symbol","children":[]},{"level":3,"title":"def to_sql(visitor : Expression::Visitor)","slug":"def-to-sql-visitor-expression-visitor","link":"#def-to-sql-visitor-expression-visitor","children":[]}]}],"relativePath":"main/Cql/AlterTable.md","lastUpdated":1723931959000}'),t={name:"main/Cql/AlterTable.md"},r=e("div",null,[e("h1",{id:"class-cql-altertable",tabindex:"-1"},[l("class Cql::AlterTable "),e("a",{class:"header-anchor",href:"#class-cql-altertable","aria-hidden":"true"},"#")]),e("p",null,[e("code",null,"Reference"),l(" < "),e("code",null,"Object")]),e("p",null,"This module is part of the Cql namespace and is responsible for handling database alterations. This class represents an AlterTable object."),e("p",null,[e("strong",null,"Example"),l(" :")]),e("div",{class:"language-crystal"},[e("button",{title:"Copy Code",class:"copy"}),e("span",{class:"lang"},"crystal"),e("pre",{"v-pre":"",class:"shiki material-theme-palenight",tabindex:"0"},[e("code",null,[e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"alter_table "),e("span",{style:{color:"#89DDFF"}},"="),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#FFCB6B"}},"AlterTable"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#BABED8"}},"new")]),l(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"alter_table"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#82AAFF"}},"add_column"),e("span",{style:{color:"#89DDFF"}},"(:email,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},'"'),e("span",{style:{color:"#C3E88D"}},"string"),e("span",{style:{color:"#89DDFF"}},'"'),e("span",{style:{color:"#89DDFF"}},")")]),l(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"alter_table"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#82AAFF"}},"drop_column"),e("span",{style:{color:"#89DDFF"}},"(:age)")]),l(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"alter_table"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#82AAFF"}},"rename_column"),e("span",{style:{color:"#89DDFF"}},"(:email,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},":user_email)")]),l(`
`),e("span",{class:"line"},[e("span",{style:{color:"#BABED8"}},"alter_table"),e("span",{style:{color:"#89DDFF"}},"."),e("span",{style:{color:"#82AAFF"}},"change_column"),e("span",{style:{color:"#89DDFF"}},"(:age,"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#89DDFF"}},'"'),e("span",{style:{color:"#C3E88D"}},"string"),e("span",{style:{color:"#89DDFF"}},'"'),e("span",{style:{color:"#89DDFF"}},")")]),l(`
`),e("span",{class:"line"}),l(`
`),e("span",{class:"line"},[e("span",{style:{color:"#89DDFF"}},"=>"),e("span",{style:{color:"#BABED8"}}," "),e("span",{style:{color:"#676E95","font-style":"italic"}},"#<AlterTable:0x00007f8e7a4e1e80>")]),l(`
`),e("span",{class:"line"})])])]),e("details",{class:"details custom-block"},[e("summary",null,"Table of Contents"),e("nav",{class:"table-of-contents"},[e("ul",null,[e("li",null,[e("a",{href:"#constructors"},"Constructors"),e("ul",null,[e("li",null,[e("a",{href:"#def-new-table-cql-table-schema-cql-schema"},"def new(table : Cql::Table, schema : Cql::Schema)")])])]),e("li",null,[e("a",{href:"#instance-methods"},"Instance Methods"),e("ul",null,[e("li",null,[e("a",{href:"#def-add-column-name-symbol-type-any-as-as-name-string-nil-nil-null-bool-true-default-db-any-nil-unique-bool-false-size-int32-nil-nil-index-bool-false"},"def add_column(name : Symbol, type : Any, as as_name : String | Nil = nil, null : Bool = true, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)")]),e("li",null,[e("a",{href:"#def-change-column-name-symbol-type-any"},"def change_column(name : Symbol, type : Any)")]),e("li",null,[e("a",{href:"#def-create-index-name-symbol-columns-array-symbol-unique-bool-false"},"def create_index(name : Symbol, columns : Array(Symbol), unique : Bool = false)")]),e("li",null,[e("a",{href:"#def-drop-column-column-symbol"},"def drop_column(column : Symbol)")]),e("li",null,[e("a",{href:"#def-drop-foreign-key-name-symbol"},"def drop_foreign_key(name : Symbol)")]),e("li",null,[e("a",{href:"#def-drop-index-name-symbol"},"def drop_index(name : Symbol)")]),e("li",null,[e("a",{href:"#def-foreign-key-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action"},'def foreign_key(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = "NO ACTION", on_update : String = "NO ACTION")')]),e("li",null,[e("a",{href:"#def-rename-column-old-name-symbol-new-name-symbol"},"def rename_column(old_name : Symbol, new_name : Symbol)")]),e("li",null,[e("a",{href:"#def-rename-table-new-name-symbol"},"def rename_table(new_name : Symbol)")]),e("li",null,[e("a",{href:"#def-to-sql-visitor-expression-visitor"},"def to_sql(visitor : Expression::Visitor)")])])])])])])],-1),i=o(`<h2 id="constructors" tabindex="-1">Constructors <a class="header-anchor" href="#constructors" aria-hidden="true">#</a></h2><h3 id="def-new-table-cql-table-schema-cql-schema" tabindex="-1">def new<code>(table : Cql::Table, schema : Cql::Schema)</code> <a class="header-anchor" href="#def-new-table-cql-table-schema-cql-schema" aria-hidden="true">#</a></h3><h2 id="instance-methods" tabindex="-1">Instance Methods <a class="header-anchor" href="#instance-methods" aria-hidden="true">#</a></h2><h3 id="def-add-column-name-symbol-type-any-as-as-name-string-nil-nil-null-bool-true-default-db-any-nil-unique-bool-false-size-int32-nil-nil-index-bool-false" tabindex="-1">def add_column<code>(name : Symbol, type : Any, as as_name : String | Nil = nil, null : Bool = true, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)</code> <a class="header-anchor" href="#def-add-column-name-symbol-type-any-as-as-name-string-nil-nil-null-bool-true-default-db-any-nil-unique-bool-false-size-int32-nil-nil-index-bool-false" aria-hidden="true">#</a></h3><p>Adds a new column to the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the column to be added</li><li><strong>@param</strong> type [Any] the data type of the column</li><li><strong>@param</strong> as_name [String, nil] an optional alias for the column</li><li><strong>@param</strong> null [Bool] whether the column allows null values (default: true)</li><li><strong>@param</strong> default [DB::Any, nil] the default value for the column (default: nil)</li><li><strong>@param</strong> unique [Bool] whether the column should have a unique constraint (default: false)</li><li><strong>@param</strong> size [Int32, nil] the size of the column (default: nil)</li><li><strong>@param</strong> index [Bool] whether the column should be indexed (default: false)</li></ul><p><strong>Example</strong> Adding a new column with default options</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">add_column</span><span style="color:#89DDFF;">(:email,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">&quot;</span><span style="color:#C3E88D;">string</span><span style="color:#89DDFF;">&quot;</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><p><strong>Example</strong> Adding a new column with custom options</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">add_column</span><span style="color:#89DDFF;">(:age,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">&quot;</span><span style="color:#C3E88D;">integer</span><span style="color:#89DDFF;">&quot;</span><span style="color:#89DDFF;">,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">null:</span><span style="color:#BABED8;"> </span><span style="color:#FF9CAC;">false</span><span style="color:#89DDFF;">,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">default:</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">&quot;</span><span style="color:#C3E88D;">18</span><span style="color:#89DDFF;">&quot;</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-change-column-name-symbol-type-any" tabindex="-1">def change_column<code>(name : Symbol, type : Any)</code> <a class="header-anchor" href="#def-change-column-name-symbol-type-any" aria-hidden="true">#</a></h3><p>Changes the type of a column in the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the column to be changed</li><li><strong>@param</strong> type [Any] the new data type for the column</li></ul><p><strong>Example</strong> Changing the type of a column</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">change_column</span><span style="color:#89DDFF;">(:age,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">&quot;</span><span style="color:#C3E88D;">string</span><span style="color:#89DDFF;">&quot;</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-create-index-name-symbol-columns-array-symbol-unique-bool-false" tabindex="-1">def create_index<code>(name : Symbol, columns : Array(Symbol), unique : Bool = false)</code> <a class="header-anchor" href="#def-create-index-name-symbol-columns-array-symbol-unique-bool-false" aria-hidden="true">#</a></h3><p>Creates an index on the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the index</li><li><strong>@param</strong> columns [Array(Symbol)] the columns to be indexed</li><li><strong>@param</strong> unique [Bool] whether the index should be unique (default: false)</li></ul><p><strong>Example</strong> Creating an index</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">create_index</span><span style="color:#89DDFF;">(:index_users_on_email,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">[:email],</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">unique:</span><span style="color:#BABED8;"> </span><span style="color:#FF9CAC;">true</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-drop-column-column-symbol" tabindex="-1">def drop_column<code>(column : Symbol)</code> <a class="header-anchor" href="#def-drop-column-column-symbol" aria-hidden="true">#</a></h3><p>Drops a column from the table.</p><ul><li><strong>@param</strong> column [Symbol] the name of the column to be dropped</li></ul><p><strong>Example</strong> Dropping a column</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">drop_column</span><span style="color:#89DDFF;">(:age)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-drop-foreign-key-name-symbol" tabindex="-1">def drop_foreign_key<code>(name : Symbol)</code> <a class="header-anchor" href="#def-drop-foreign-key-name-symbol" aria-hidden="true">#</a></h3><p>Drops a foreign key from the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the foreign key to be dropped</li></ul><p><strong>Example</strong> Dropping a foreign key</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">drop_foreign_key</span><span style="color:#89DDFF;">(:fk_user_id)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-drop-index-name-symbol" tabindex="-1">def drop_index<code>(name : Symbol)</code> <a class="header-anchor" href="#def-drop-index-name-symbol" aria-hidden="true">#</a></h3><p>Drops an index from the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the index to be dropped</li></ul><p><strong>Example</strong> Dropping an index</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">drop_index</span><span style="color:#89DDFF;">(:index_users_on_email)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-foreign-key-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action" tabindex="-1">def foreign_key<code>(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = &quot;NO ACTION&quot;, on_update : String = &quot;NO ACTION&quot;)</code> <a class="header-anchor" href="#def-foreign-key-name-symbol-columns-array-symbol-table-symbol-references-array-symbol-on-delete-string-no-action-on-update-string-no-action" aria-hidden="true">#</a></h3><p>Adds a foreign key to the table.</p><ul><li><strong>@param</strong> name [Symbol] the name of the foreign key</li><li><strong>@param</strong> columns [Array(Symbol)] the columns in the current table</li><li><strong>@param</strong> table [Symbol] the referenced table</li><li><strong>@param</strong> references [Array(Symbol)] the columns in the referenced table</li><li><strong>@param</strong> on_delete [String] the action on delete (default: &quot;NO ACTION&quot;)</li><li><strong>@param</strong> on_update [String] the action on update (default: &quot;NO ACTION&quot;)</li></ul><p><strong>Example</strong> Adding a foreign key</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">foreign_key</span><span style="color:#89DDFF;">(:fk_user_id,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">[:user_id],</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">:users,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">[:id],</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">on_delete:</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">&quot;</span><span style="color:#C3E88D;">CASCADE</span><span style="color:#89DDFF;">&quot;</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-rename-column-old-name-symbol-new-name-symbol" tabindex="-1">def rename_column<code>(old_name : Symbol, new_name : Symbol)</code> <a class="header-anchor" href="#def-rename-column-old-name-symbol-new-name-symbol" aria-hidden="true">#</a></h3><p>Renames a column in the table.</p><ul><li><strong>@param</strong> old_name [Symbol] the current name of the column</li><li><strong>@param</strong> new_name [Symbol] the new name for the column</li></ul><p><strong>Example</strong> Renaming a column</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#BABED8;">  </span><span style="color:#82AAFF;">rename_column</span><span style="color:#89DDFF;">(:email,</span><span style="color:#BABED8;"> </span><span style="color:#89DDFF;">:user_email)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-rename-table-new-name-symbol" tabindex="-1">def rename_table<code>(new_name : Symbol)</code> <a class="header-anchor" href="#def-rename-table-new-name-symbol" aria-hidden="true">#</a></h3><p>Renames the table.</p><ul><li><strong>@param</strong> new_name [Symbol] the new name for the table</li></ul><p><strong>Example</strong> Renaming the table</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#82AAFF;">rename_table</span><span style="color:#89DDFF;">(:new_table_name)</span></span>
<span class="line"></span></code></pre></div><h3 id="def-to-sql-visitor-expression-visitor" tabindex="-1">def to_sql<code>(visitor : Expression::Visitor)</code> <a class="header-anchor" href="#def-to-sql-visitor-expression-visitor" aria-hidden="true">#</a></h3><p>Converts the alter table actions to SQL.</p><ul><li><strong>@param</strong> visitor [Expression::Visitor] the visitor to generate SQL</li><li><strong>@return</strong> [String] the generated SQL</li></ul><p><strong>Example</strong> Generating SQL for alter table actions</p><div class="language-crystal"><button title="Copy Code" class="copy"></button><span class="lang">crystal</span><pre class="shiki material-theme-palenight" tabindex="0"><code><span class="line"><span style="color:#BABED8;">sql </span><span style="color:#89DDFF;">=</span><span style="color:#BABED8;"> </span><span style="color:#82AAFF;">to_sql</span><span style="color:#89DDFF;">(</span><span style="color:#BABED8;">visitor</span><span style="color:#89DDFF;">)</span></span>
<span class="line"></span></code></pre></div><p>:::</p>`,56),c=[r,i];function p(d,m,y,u,b,h){return a(),s("div",null,c)}const F=n(t,[["render",p]]);export{D as __pageData,F as default};
