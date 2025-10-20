/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "indexes": []
  }, collection)

  // remove field
  collection.fields.removeById("text521872670")

  // remove field
  collection.fields.removeById("number158830993")

  // remove field
  collection.fields.removeById("text105650625")

  // remove field
  collection.fields.removeById("text700514382")

  // add field
  collection.fields.addAt(1, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_3665455462",
    "hidden": false,
    "id": "relation700514382",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "video_id",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // add field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "json1761844607",
    "maxSize": 0,
    "name": "detections",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "json"
  }))

  // add field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "json1902111303",
    "maxSize": 0,
    "name": "changes_summary",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "json"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE INDEX `idx_9imYgQo0m2` ON `results` (\n  `timestamp`,\n  `item`\n)"
    ]
  }, collection)

  // add field
  collection.fields.addAt(1, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text521872670",
    "max": 0,
    "min": 0,
    "name": "item",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(2, new Field({
    "hidden": false,
    "id": "number158830993",
    "max": null,
    "min": null,
    "name": "confidence",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // add field
  collection.fields.addAt(3, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text105650625",
    "max": 0,
    "min": 0,
    "name": "category",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(5, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text700514382",
    "max": 0,
    "min": 0,
    "name": "video_id",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // remove field
  collection.fields.removeById("relation700514382")

  // remove field
  collection.fields.removeById("json1761844607")

  // remove field
  collection.fields.removeById("json1902111303")

  return app.save(collection)
})
