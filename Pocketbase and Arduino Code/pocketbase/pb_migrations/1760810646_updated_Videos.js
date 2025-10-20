/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE INDEX `idx_ol0YvLejzq` ON `videos` (\n  `processed`,\n  `timestamp`\n)"
    ],
    "name": "videos"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE INDEX `idx_ol0YvLejzq` ON `Videos` (\n  `processed`,\n  `timestamp`\n)"
    ],
    "name": "Videos"
  }, collection)

  return app.save(collection)
})
