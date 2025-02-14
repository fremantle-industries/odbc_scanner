#pragma once

#include "duckdb.hpp"

namespace duckdb {
class Odbc_scannerExtension : public Extension {
public:
  void Load(DuckDB &db) override;
  std::string Name() override;
};
} // namespace duckdb
