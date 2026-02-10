#ifndef __SE_DB_TEST_MQH__
#define __SE_DB_TEST_MQH__

#include "SEDb.mqh"
#include "../SETest/SETest.mqh"

class SEDbTest {
private:
	SETest test;
	SEDb database;

	void TestInsertAndCount() {
		test.Describe("InsertOne & Count");

		SEDbCollection *collection = database.Collection("test_insert");
		collection.SetAutoFlush(false);

		test.AssertEquals(collection.Count(), 0, "Collection starts empty");

		JSON::Object *document = new JSON::Object();
		document.setProperty("name", "Alice");
		document.setProperty("age", 30);
		bool inserted = collection.InsertOne(document);
		delete document;

		test.AssertTrue(inserted, "InsertOne returns true");
		test.AssertEquals(collection.Count(), 1, "Count is 1 after insert");

		JSON::Object *document2 = new JSON::Object();
		document2.setProperty("name", "Bob");
		document2.setProperty("age", 25);
		collection.InsertOne(document2);
		delete document2;

		test.AssertEquals(collection.Count(), 2, "Count is 2 after second insert");

		JSON::Object *found = collection.FindOne("name", "Alice");
		test.AssertNotNull(found, "FindOne returns inserted document");
		test.AssertTrue(found.hasValue("_id"), "Auto-generated _id exists");
		test.AssertEquals(found.getString("name"), "Alice", "FindOne returns correct name");
		test.AssertEquals((int)found.getNumber("age"), 30, "FindOne returns correct age");

		database.Drop("test_insert");
	}

	void TestInsertPreservesId() {
		test.Describe("InsertOne preserves _id");

		SEDbCollection *collection = database.Collection("test_preserve_id");
		collection.SetAutoFlush(false);

		JSON::Object *document = new JSON::Object();
		document.setProperty("_id", "custom_id_123");
		document.setProperty("name", "Charlie");
		collection.InsertOne(document);
		delete document;

		JSON::Object *found = collection.FindOne("_id", "custom_id_123");
		test.AssertNotNull(found, "FindOne by custom _id");
		test.AssertEquals(found.getString("_id"), "custom_id_123", "Custom _id preserved");

		database.Drop("test_preserve_id");
	}

	void TestFindOne() {
		test.Describe("FindOne");

		SEDbCollection *collection = database.Collection("test_find_one");
		collection.SetAutoFlush(false);

		JSON::Object *d1 = new JSON::Object();
		d1.setProperty("code", "A1");
		d1.setProperty("value", 100);
		collection.InsertOne(d1);
		delete d1;

		JSON::Object *d2 = new JSON::Object();
		d2.setProperty("code", "B2");
		d2.setProperty("value", 200);
		collection.InsertOne(d2);
		delete d2;

		test.AssertNotNull(collection.FindOne("code", "A1"), "FindOne existing key");
		test.AssertNotNull(collection.FindOne("code", "B2"), "FindOne second document");
		test.AssertNull(collection.FindOne("code", "C3"), "FindOne non-existing returns NULL");
		test.AssertNull(collection.FindOne("missing_field", "x"), "FindOne missing field returns NULL");

		database.Drop("test_find_one");
	}

	void TestFind() {
		test.Describe("Find with Query");

		SEDbCollection *collection = database.Collection("test_find");
		collection.SetAutoFlush(false);

		for (int i = 1; i <= 5; i++) {
			JSON::Object *document = new JSON::Object();
			document.setProperty("index", i);
			document.setProperty("category", i <= 3 ? "low" : "high");
			collection.InsertOne(document);
			delete document;
		}

		test.AssertEquals(collection.Count(), 5, "5 documents inserted");

		SEDbQuery queryLow;
		queryLow.WhereEquals("category", "low");
		JSON::Object *lowResults[];
		int lowCount = collection.Find(queryLow, lowResults);
		test.AssertEquals(lowCount, 3, "Find category=low returns 3");

		SEDbQuery queryHigh;
		queryHigh.WhereEquals("category", "high");
		JSON::Object *highResults[];
		int highCount = collection.Find(queryHigh, highResults);
		test.AssertEquals(highCount, 2, "Find category=high returns 2");

		SEDbQuery queryGreater;
		queryGreater.WhereGreaterThan("index", 3.0);
		JSON::Object *greaterResults[];
		int greaterCount = collection.Find(queryGreater, greaterResults);
		test.AssertEquals(greaterCount, 2, "Find index > 3 returns 2");

		SEDbQuery queryRange;
		queryRange.WhereGreaterThanOrEqual("index", 2.0);
		queryRange.WhereLessThanOrEqual("index", 4.0);
		JSON::Object *rangeResults[];
		int rangeCount = collection.Find(queryRange, rangeResults);
		test.AssertEquals(rangeCount, 3, "Find 2 <= index <= 4 returns 3");

		SEDbQuery queryNone;
		queryNone.WhereEquals("category", "medium");
		JSON::Object *noneResults[];
		int noneCount = collection.Find(queryNone, noneResults);
		test.AssertEquals(noneCount, 0, "Find non-existing category returns 0");

		database.Drop("test_find");
	}

	void TestQueryContains() {
		test.Describe("Query WhereContains");

		SEDbCollection *collection = database.Collection("test_contains");
		collection.SetAutoFlush(false);

		JSON::Object *d1 = new JSON::Object();
		d1.setProperty("description", "gold strategy long");
		collection.InsertOne(d1);
		delete d1;

		JSON::Object *d2 = new JSON::Object();
		d2.setProperty("description", "silver strategy short");
		collection.InsertOne(d2);
		delete d2;

		JSON::Object *d3 = new JSON::Object();
		d3.setProperty("description", "gold scalping");
		collection.InsertOne(d3);
		delete d3;

		SEDbQuery query;
		query.WhereContains("description", "gold");
		JSON::Object *results[];
		int count = collection.Find(query, results);
		test.AssertEquals(count, 2, "WhereContains 'gold' returns 2");

		SEDbQuery queryStrategy;
		queryStrategy.WhereContains("description", "strategy");
		JSON::Object *strategyResults[];
		int strategyCount = collection.Find(queryStrategy, strategyResults);
		test.AssertEquals(strategyCount, 2, "WhereContains 'strategy' returns 2");

		database.Drop("test_contains");
	}

	void TestUpdateOne() {
		test.Describe("UpdateOne");

		SEDbCollection *collection = database.Collection("test_update");
		collection.SetAutoFlush(false);

		JSON::Object *document = new JSON::Object();
		document.setProperty("_id", "upd_1");
		document.setProperty("name", "Original");
		document.setProperty("score", 10);
		collection.InsertOne(document);
		delete document;

		JSON::Object *updateData = new JSON::Object();
		updateData.setProperty("name", "Updated");
		updateData.setProperty("score", 99);
		updateData.setProperty("newField", "added");
		bool updated = collection.UpdateOne("_id", "upd_1", updateData);
		delete updateData;

		test.AssertTrue(updated, "UpdateOne returns true");

		JSON::Object *found = collection.FindOne("_id", "upd_1");
		test.AssertNotNull(found, "Document still exists after update");
		test.AssertEquals(found.getString("name"), "Updated", "Name field updated");
		test.AssertEquals((int)found.getNumber("score"), 99, "Score field updated");
		test.AssertEquals(found.getString("newField"), "added", "New field added via update");

		JSON::Object *failData = new JSON::Object();
		failData.setProperty("name", "Ghost");
		bool failUpdate = collection.UpdateOne("_id", "nonexistent", failData);
		delete failData;

		test.AssertFalse(failUpdate, "UpdateOne on missing document returns false");

		database.Drop("test_update");
	}

	void TestDeleteOne() {
		test.Describe("DeleteOne");

		SEDbCollection *collection = database.Collection("test_delete");
		collection.SetAutoFlush(false);

		JSON::Object *d1 = new JSON::Object();
		d1.setProperty("_id", "del_1");
		d1.setProperty("name", "Keep");
		collection.InsertOne(d1);
		delete d1;

		JSON::Object *d2 = new JSON::Object();
		d2.setProperty("_id", "del_2");
		d2.setProperty("name", "Remove");
		collection.InsertOne(d2);
		delete d2;

		test.AssertEquals(collection.Count(), 2, "2 documents before delete");

		bool deleted = collection.DeleteOne("_id", "del_2");
		test.AssertTrue(deleted, "DeleteOne returns true");
		test.AssertEquals(collection.Count(), 1, "Count is 1 after delete");
		test.AssertNull(collection.FindOne("_id", "del_2"), "Deleted document not found");
		test.AssertNotNull(collection.FindOne("_id", "del_1"), "Other document still exists");

		bool failDelete = collection.DeleteOne("_id", "nonexistent");
		test.AssertFalse(failDelete, "DeleteOne on missing document returns false");

		database.Drop("test_delete");
	}

	void TestFlushAndLoad() {
		test.Describe("Flush & Load (persistence)");

		SEDbCollection *writeCollection = database.Collection("test_persistence");
		writeCollection.SetAutoFlush(false);

		JSON::Object *d1 = new JSON::Object();
		d1.setProperty("_id", "persist_1");
		d1.setProperty("name", "Persisted");
		d1.setProperty("value", 42);
		writeCollection.InsertOne(d1);
		delete d1;

		JSON::Object *d2 = new JSON::Object();
		d2.setProperty("_id", "persist_2");
		d2.setProperty("name", "AlsoPersisted");
		d2.setProperty("value", 84);
		writeCollection.InsertOne(d2);
		delete d2;

		bool flushed = writeCollection.Flush();
		test.AssertTrue(flushed, "Flush returns true");

		database.Drop("test_persistence");

		SEDbCollection *readCollection = database.Collection("test_persistence");

		test.AssertEquals(readCollection.Count(), 2, "Loaded 2 documents from disk");

		JSON::Object *loaded = readCollection.FindOne("_id", "persist_1");
		test.AssertNotNull(loaded, "Persisted document found after reload");
		if (loaded != NULL) {
			test.AssertEquals(loaded.getString("name"), "Persisted", "Persisted name matches");
			test.AssertEquals((int)loaded.getNumber("value"), 42, "Persisted value matches");
		}

		database.Drop("test_persistence");
	}

	void TestDatabaseCollectionManager() {
		test.Describe("SEDb Collection Manager");

		test.AssertEquals(database.GetCollectionCount(), 0, "No collections initially");

		SEDbCollection *c1 = database.Collection("test_manager_a");
		c1.SetAutoFlush(false);
		test.AssertEquals(database.GetCollectionCount(), 1, "1 collection after first access");

		SEDbCollection *c2 = database.Collection("test_manager_b");
		c2.SetAutoFlush(false);
		test.AssertEquals(database.GetCollectionCount(), 2, "2 collections after second access");

		SEDbCollection *c1Again = database.Collection("test_manager_a");
		test.AssertEquals(database.GetCollectionCount(), 2, "Same collection returned, count still 2");
		test.Assert(c1 == c1Again, "Same pointer returned for same name");

		bool dropped = database.Drop("test_manager_a");
		test.AssertTrue(dropped, "Drop returns true");
		test.AssertEquals(database.GetCollectionCount(), 1, "1 collection after drop");

		bool failDrop = database.Drop("nonexistent");
		test.AssertFalse(failDrop, "Drop non-existing returns false");

		database.Drop("test_manager_b");
		test.AssertEquals(database.GetCollectionCount(), 0, "0 collections after dropping all");
	}

	void TestQueryNotEquals() {
		test.Describe("Query WhereNotEquals");

		SEDbCollection *collection = database.Collection("test_not_equals");
		collection.SetAutoFlush(false);

		JSON::Object *d1 = new JSON::Object();
		d1.setProperty("status", "active");
		collection.InsertOne(d1);
		delete d1;

		JSON::Object *d2 = new JSON::Object();
		d2.setProperty("status", "closed");
		collection.InsertOne(d2);
		delete d2;

		JSON::Object *d3 = new JSON::Object();
		d3.setProperty("status", "active");
		collection.InsertOne(d3);
		delete d3;

		SEDbQuery query;
		query.WhereNotEquals("status", "active");
		JSON::Object *results[];
		int count = collection.Find(query, results);
		test.AssertEquals(count, 1, "WhereNotEquals 'active' returns 1");

		database.Drop("test_not_equals");
	}

	void TestQueryReset() {
		test.Describe("Query Reset");

		SEDbQuery query;
		query.WhereEquals("field", "value");
		test.AssertEquals(query.GetConditionCount(), 1, "1 condition after WhereEquals");

		query.Reset();
		test.AssertEquals(query.GetConditionCount(), 0, "0 conditions after Reset");

		query.WhereGreaterThan("score", 50.0);
		query.WhereLessThan("score", 100.0);
		test.AssertEquals(query.GetConditionCount(), 2, "2 conditions after chained Where");
	}

public:
	SEDbTest() {
	}

	bool Run() {
		test.SetSuiteName("SEDbTest");

		database.Initialize("SEDbTest");

		TestInsertAndCount();
		TestInsertPreservesId();
		TestFindOne();
		TestFind();
		TestQueryContains();
		TestQueryNotEquals();
		TestQueryReset();
		TestUpdateOne();
		TestDeleteOne();
		TestFlushAndLoad();
		TestDatabaseCollectionManager();

		test.PrintSummary();
		return !test.HasFailed();
	}
};

#endif
