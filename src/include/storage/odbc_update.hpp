#pragma once

#include "duckdb/execution/physical_operator.hpp"
#include "duckdb/common/index_vector.hpp"

namespace duckdb {

class OdbcUpdate : public PhysicalOperator {
public:
	OdbcUpdate(LogicalOperator &op, TableCatalogEntry &table, vector<PhysicalIndex> columns);

	//! The table to delete from
	TableCatalogEntry &table;
	//! The set of columns to update
	vector<PhysicalIndex> columns;

public:
	// Source interface
	SourceResultType GetData(ExecutionContext &context, DataChunk &chunk, OperatorSourceInput &input) const override;

	bool IsSource() const override {
		return true;
	}

public:
	// Sink interface
	unique_ptr<GlobalSinkState> GetGlobalSinkState(ClientContext &context) const override;
	SinkResultType Sink(ExecutionContext &context, DataChunk &chunk, OperatorSinkInput &input) const override;

	bool IsSink() const override {
		return true;
	}

	bool ParallelSink() const override {
		return false;
	}

	string GetName() const override;
	string ParamsToString() const override;
};

} // namespace duckdb
