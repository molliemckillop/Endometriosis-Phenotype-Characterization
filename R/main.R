# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of EndometriosisCharacterization
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Initialize EndometriosisCharacterization Study Tables
#'
#' @details
#' This function initializes the Endometriosis Characterization Study tables.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param targetDatabaseSchema The schema to contain the study results tables
#'
#' @param tablePrefix          A prefix to add to the study tables
#'
#' @examples
#' \dontrun{
#' connectionDetails <- DatatbaseConnector:: createConnectionDetails(dbms = "postgresql",
#'                                              user = "joe",
#'                                              password = "secret",
#'                                              server = "myserver")
#'
#' execute(connectionDetails,
#'         targetDatabaseSchema = "studyDB.endoStudy",
#'         tablePrefix="endo_")
#' }
#'
#' @export
init <- function(connectionDetails, targetDatabaseSchema, tablePrefix="") {

	conn <- DatabaseConnector::connect(connectionDetails);

	# Create study cohort table structure:
	sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CreateCohortTable.sql",
																					 packageName = packageName(),
																					 dbms = attr(conn, "dbms"),
																					 cohort_database_schema = targetDatabaseSchema,
																					 cohort_table = paste0(tablePrefix, "cohort"))

	DatabaseConnector::executeSql(conn, sql, progressBar = TRUE, reportOverallTime = FALSE)
	DatabaseConnector::dbDisconnect(conn);

	invisible(NULL)
}

#' Execute EndometriosisCharacterization Study
#'
#' @details
#' This function executes the Endometriosis Characterization Study.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param cdmDatabaseSchema    Schema name where your patient-level data in OMOP CDM format resides.
#'                             Note that for SQL Server, this should include both the database and
#'                             schema name, for example 'cdm_data.dbo'.
#' @param oracleTempSchema     Should be used in Oracle to specify a schema where the user has write
#'                             priviliges for storing temporary tables.
#' @param tablePrefix          The prefix for the study tables, should be same value used in init()
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#'
#' @examples
#' \dontrun{
#' connectionDetails <- createConnectionDetails(dbms = "postgresql",
#'                                              user = "joe",
#'                                              password = "secret",
#'                                              server = "myserver")
#'
#' execute(connectionDetails,
#'         cdmDatabaseSchema = "cdm_data",
#'         targetDatabaseSchema = "results",
#'         oracleTempSchema = NULL,
#'         tablePrefix = "endo_",
#'         outputFolder = "c:/temp/study_results")
#' }
#'
#' @export
execute <- function(connectionDetails,
										cdmDatabaseSchema,
										targetDatabaseSchema,
										oracleTempSchema = cdmDatabaseSchema,
										tablePrefix = "",
										outputFolder,
										createCohorts = TRUE) {
	if (!file.exists(outputFolder))
		dir.create(outputFolder, recursive = TRUE)

	OhdsiRTools::addDefaultFileLogger(file.path(outputFolder, "log.txt"))

	conn <- DatabaseConnector::connect(connectionDetails)

	if (createCohorts) {
		# instantiate cohorts
		.createCohorts(connection = conn,
									 cdmDatabaseSchema = cdmDatabaseSchema,
									 targetDatabaseSchema = targetDatabaseSchema,
									 oracleTempSchema = oracleTempSchema,
									 cohortTable = paste0(tablePrefix, "cohort"))
	}

	pathToCsv <- system.file("settings", "cohorts.csv", package = packageName())

	cohortsCsv<- read.csv(pathToCsv,stringsAsFactors = FALSE)

	cohortTable <- paste0(tablePrefix, "cohort")

	for (i in 1:nrow(cohortsCsv)) {

		# Total Counts
		OhdsiRTools::logInfo(paste0("Total Counts for cohort: ", cohortsCsv$shortName[i]))

		totalCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "TotalCount.sql",
																						 packageName = packageName(),
																						 dbms = attr(conn, "dbms"),
																						 cohortId = cohortsCsv$cohortId[i],
																						 target_database_schema = targetDatabaseSchema,
																						 target_cohort_table = cohortTable)
		totalCount <- DatabaseConnector::querySql(conn, totalCountSql);

		fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i], ".csv"))
		write.csv(totalCount, file = fileName, row.names=FALSE, na="")


		# Counts with DE Prior
		OhdsiRTools::logInfo(paste0("Persons with DE Prior for cohort: ", cohortsCsv$shortName[i]))

		dePriorCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CountWithDEPrior.sql",
																											 packageName = packageName(),
																											 dbms = attr(conn, "dbms"),
																											 CDM_schema = cdmDatabaseSchema,
																											 cohortId = cohortsCsv$cohortId[i],
																											 target_database_schema = targetDatabaseSchema,
																											 target_cohort_table = cohortTable)
		dePriorCount <- DatabaseConnector::querySql(conn, dePriorCountSql);

		fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i],"_DE_before_cohort_start.csv"))
		write.csv(dePriorCount, file = fileName, row.names=FALSE, na="")

		# Counts with CO Prior
		OhdsiRTools::logInfo(paste0("Persons with CO Prior for cohort: ", cohortsCsv$shortName[i]))

		coPriorCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CountWithCOPrior.sql",
																												 packageName = packageName(),
																												 dbms = attr(conn, "dbms"),
																												 CDM_schema = cdmDatabaseSchema,
																												 cohortId = cohortsCsv$cohortId[i],
																												 target_database_schema = targetDatabaseSchema,
																												 target_cohort_table = cohortTable)
		coPriorCount <- DatabaseConnector::querySql(conn, coPriorCountSql);

		fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i],"_CO_before_cohort_start.csv"))
		write.csv(coPriorCount, file = fileName, row.names=FALSE, na="")

		# Drug Counts, prior to index
		OhdsiRTools::logInfo(paste0("Drug Counts prior to index for cohort: ", cohortsCsv$shortName[i]))

		drugCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "DrugCount.sql",
																												 packageName = packageName(),
																												 dbms = attr(conn, "dbms"),
																												 CDM_schema = cdmDatabaseSchema,
																												 cohortId = cohortsCsv$cohortId[i],
																												 target_database_schema = targetDatabaseSchema,
																												 target_cohort_table = cohortTable)
		drugCount <- DatabaseConnector::querySql(conn, drugCountSql);

		fileName <- file.path(outputFolder, paste0("drugs_", cohortsCsv$shortName[i], ".csv"))
		write.csv(drugCount, file = fileName, row.names=FALSE, na="")

		# Condition Counts, prior to index
		OhdsiRTools::logInfo(paste0("Condition Counts prior to index for cohort: ", cohortsCsv$shortName[i]))

		conditionCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "ConditionCount.sql",
																											packageName = packageName(),
																											dbms = attr(conn, "dbms"),
																											CDM_schema = cdmDatabaseSchema,
																											cohortId = cohortsCsv$cohortId[i],
																											target_database_schema = targetDatabaseSchema,
																											target_cohort_table = cohortTable)
		conditionCount <- DatabaseConnector::querySql(conn, conditionCountSql);

		fileName <- file.path(outputFolder, paste0("conditions_", cohortsCsv$shortName[i], ".csv"))
		write.csv(conditionCount, file = fileName, row.names=FALSE, na="")

		# Counts with ERVisits, prior to index
		OhdsiRTools::logInfo(paste0("Persons with ER Visits prior to index for cohort: ", cohortsCsv$shortName[i]))

		erVisitCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "ERVisitCount.sql",
																													 packageName = packageName(),
																													 dbms = attr(conn, "dbms"),
																													 CDM_schema = cdmDatabaseSchema,
																													 cohortId = cohortsCsv$cohortId[i],
																													 target_database_schema = targetDatabaseSchema,
																													 target_cohort_table = cohortTable)
		erVisitCount <- DatabaseConnector::querySql(conn, erVisitCountSql);

		fileName <- file.path(outputFolder, paste0("ER_visits_", cohortsCsv$shortName[i], ".csv"))
		write.csv(erVisitCount, file = fileName, row.names=FALSE, na="")

	}


	DatabaseConnector::disconnect(conn)

	invisible(NULL)
}
