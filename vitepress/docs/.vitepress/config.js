import { fileURLToPath } from 'url'
import { dirname, join, parse } from 'path';
import { readdirSync, readFileSync } from "fs"
import { defineConfig } from 'vitepress'
import MiniSearch from 'minisearch'

const splitter = "+++"
const sidebar_folder = join(dirname(fileURLToPath(import.meta.url)), "crystal")
const sidebars = readdirSync(sidebar_folder)
const sidebars_json = {}

sidebars.forEach(x => {
  let [name, version] = x.split(splitter)
  version = parse(version).name

  const raw = readFileSync(join(sidebar_folder, x), { encoding: "utf-8" })

  sidebars_json[version] = {
    name,
    json: JSON.parse(raw)
  }
})
// NOTE: Above code imports all sidebars.

export default defineConfig({
  title: 'Cql Documentation',
  // TODO: Change me.
  description: 'My awesome Crystal project!',
  lastUpdated: true,
  ignoreDeadLinks: true,
  base: '/cql/',
  themeConfig: {
    search: {
      provider: 'minisearch',
      options: {
        // MiniSearch-specific options
        fields: ['title', 'description', 'content'], // fields to index
        storeFields: ['title', 'description'], // fields to store for display
        searchOptions: {
          boost: { title: 2 }, // boost title relevance in search
          prefix: true, // allow matching by prefix
          fuzzy: 0.2 // set fuzzy search tolerance
        }
      }
    },
    outline: {
      level: [2, 6], // Specifies which header levels to include in the TOC (e.g., from <h2> to <h6>)
      label: 'On this page' // Custom label for the outline
    },
    nav: [
      nav()
    ],
    sidebar: sidebar(),
    socialLinks: [
      { icon: 'github', link: 'https://github.com/azutoolkit/cql' }
    ]
  }
})

// NOTE: below code creates the sidebar and navbar
// based on the amount of sidebars and their contents.
function sidebar() {
  result = {}

  for (const [key, value] of Object.entries(sidebars_json)) {
    result[key] = [
      {
        text: "Cql API",
        items: value.json
      }
    ]
  }

  return result
}

function nav() {
  if (Object.keys(sidebars_json).length === 1) {
    return {
      text: 'Cql API',
      link: `${Object.values(sidebars_json)[0].json[0].link}`
    }
  }

  result = {
    text: 'Version',
    items: []
  }

  for (const [key, value] of Object.entries(sidebars_json)) {
    result.items.push({
      text: `${key}`,
      link: `${value.json[0].link}`
    })
  }

  return result
}
