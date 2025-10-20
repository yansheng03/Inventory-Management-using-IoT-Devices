/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "indexes": []
  }, collection)

  // remove field
  collection.fields.removeById("text2493827028")

  // remove field
  collection.fields.removeById("date2782324286")

  // update field
  collection.fields.addAt(1, new Field({
    "hidden": false,
    "id": "file2332584908",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "video",
    "presentable": false,
    "protected": false,
    "required": false,
    "system": false,
    "thumbs": [],
    "type": "file"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE INDEX `idx_ol0YvLejzq` ON `videos` (\n  `processed`,\n  `timestamp`\n)"
    ]
  }, collection)

  // add field
  collection.fields.addAt(2, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text2493827028",
    "max": 0,
    "min": 0,
    "name": "device_id",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "date2782324286",
    "max": "",
    "min": "",
    "name": "timestamp",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "date"
  }))

  // update field
  collection.fields.addAt(1, new Field({
    "hidden": false,
    "id": "file2332584908",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "video_file",
    "presentable": false,
    "protected": false,
    "required": false,
    "system": false,
    "thumbs": [],
    "type": "file"
  }))

  return app.save(collection)
})
