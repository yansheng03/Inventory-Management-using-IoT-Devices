/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE INDEX `idx_9imYgQo0m2` ON `results` (\n  `timestamp`,\n  `item`\n)"
    ]
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "indexes": []
  }, collection)

  return app.save(collection)
})
