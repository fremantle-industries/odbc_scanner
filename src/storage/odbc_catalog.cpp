#include "storage/odbc_catalog.hpp"
#include "duckdb/storage/database_size.hpp"
#include "odbc_db.hpp"
#include "storage/odbc_schema_entry.hpp"
#include "storage/odbc_transaction.hpp"

namespace duckdb {

OdbcCatalog::OdbcCatalog(AttachedDatabase &db_p, const string &path, AccessMode access_mode)
    : Catalog(db_p), path(path), access_mode(access_mode), in_memory(path == ":memory:"),
      active_in_memory(false) {
  if (InMemory()) {
    in_memory_db = OdbcDB::Open(path, false, true);
  }
}

OdbcCatalog::~OdbcCatalog() {}

void OdbcCatalog::Initialize(bool load_builtin) { main_schema = make_uniq<OdbcSchemaEntry>(*this); }

optional_ptr<CatalogEntry> OdbcCatalog::CreateSchema(CatalogTransaction transaction, CreateSchemaInfo &info) {
  throw BinderException("Odbc databases do not support creating new schemas");
}

void OdbcCatalog::ScanSchemas(ClientContext &context, std::function<void(SchemaCatalogEntry &)> callback) {
  callback(*main_schema);
}

optional_ptr<SchemaCatalogEntry> OdbcCatalog::GetSchema(CatalogTransaction transaction,
                                                        const string &schema_name,
                                                        OnEntryNotFound if_not_found,
                                                        QueryErrorContext error_context) {
  if (schema_name == DEFAULT_SCHEMA || schema_name == INVALID_SCHEMA) {
    return main_schema.get();
  }
  if (if_not_found == OnEntryNotFound::RETURN_NULL) {
    return nullptr;
  }
  throw BinderException("Odbc databases only have a single schema - \"%s\"", DEFAULT_SCHEMA);
}

bool OdbcCatalog::InMemory() { return in_memory; }

string OdbcCatalog::GetDBPath() { return path; }

OdbcDB *OdbcCatalog::GetInMemoryDatabase() {
  if (!InMemory()) {
    throw InternalException("GetInMemoryDatabase() called on a non-in-memory database");
  }
  lock_guard<mutex> l(in_memory_lock);
  if (active_in_memory) {
    throw TransactionException(
        "Only a single transaction can be active on an in-memory Odbc database at a time");
  }
  active_in_memory = true;
  return &in_memory_db;
}

void OdbcCatalog::ReleaseInMemoryDatabase() {
  if (!InMemory()) {
    return;
  }
  lock_guard<mutex> l(in_memory_lock);
  if (!active_in_memory) {
    throw InternalException(
        "ReleaseInMemoryDatabase called but there is no active transaction on an in-memory database");
  }
  active_in_memory = false;
}

void OdbcCatalog::DropSchema(ClientContext &context, DropInfo &info) {
  throw BinderException("Odbc databases do not support dropping schemas");
}

DatabaseSize OdbcCatalog::GetDatabaseSize(ClientContext &context) {
  DatabaseSize result;

  auto &transaction = OdbcTransaction::Get(context, *this);
  auto &db = transaction.GetDB();
  result.total_blocks = db.RunPragma("page_count");
  result.block_size = db.RunPragma("page_size");
  result.free_blocks = db.RunPragma("freelist_count");
  result.used_blocks = result.total_blocks - result.free_blocks;
  result.bytes = result.total_blocks * result.block_size;
  result.wal_size = idx_t(-1);
  return result;
}

} // namespace duckdb
