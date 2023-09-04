#pragma once

#include "duckdb/execution/physical_operator.hpp"
#include "duckdb/parser/parsed_data/create_index_info.hpp"

namespace duckdb {

//! PhysicalCreateSequence represents a CREATE SEQUENCE command
class OdbcCreateIndex : public PhysicalOperator {
public:
	explicit OdbcCreateIndex(unique_ptr<CreateIndexInfo> info, TableCatalogEntry &table);

	unique_ptr<CreateIndexInfo> info;
	TableCatalogEntry &table;

public:
	// Source interface
	SourceResultType GetData(ExecutionContext &context, DataChunk &chunk, OperatorSourceInput &input) const override;

	bool IsSource() const override {
		return true;
	}
};

} // namespace duckdb
