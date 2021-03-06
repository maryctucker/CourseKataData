context("Processing responses")

library(dplyr)
library(vctrs)
library(fs)
library(zip)

mock_response_looktbl <- data.frame(
  student_id = 1,
  prompt = "text",
  lrn_question_reference = c(1, 2, 1, 3),
  lrn_type = c("mcq", "plaintext", "mcq", "mcq"),
  response = c('["1"]', '["2"]', '["0", "1"]', "[]"),
  lrn_option_0 = c("Yes", 1, "Yes", "50"),
  lrn_option_1 = c("No", 2, "No", "60"),
  lrn_option_2 = c(NA, "Three", NA, "70")
)

mock_responses_integration <- data.frame(
  class_id = 1,
  student_id = 1,
  prompt = 1,
  response = 1,
  lrn_type = 1,
  lrn_question_reference = 1
)

mock_integration_processed <- process_responses(mock_responses_integration)

top_dir <- path_temp("data_download")
class_dir <- dir_create(path(top_dir, "classes", c("class_1", "class_2")))

resp_file_1 <- path(class_dir[[1]], "responses", ext = "csv")
resp_file_2 <- path(class_dir[[2]], "responses", ext = "csv")
write.csv(mock_responses_integration, resp_file_1, row.names = FALSE)
write.csv(mock_responses_integration, resp_file_2, row.names = FALSE)

zip_file <- file_temp(ext = ".zip")
zipr(zip_file, top_dir)


# Tests: Type conversion --------------------------------------------------

test_that("integer columns are appropriately typed if they exist", {
  # this mock should have all expected integer columns
  mock_response <- data.frame(
    attempt = "1",
    lrn_question_position = "1"
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response),
    names(mock_response),
    integer()
  )
})

test_that("numeric columns are appropriately typed if they exist", {
  # this mock should have all expected numeric columns
  mock_response <- data.frame(
    points_possible = "1",
    points_earned = "1"
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response),
    names(mock_response),
    numeric()
  )
})

test_that("datetime columns are appropriately typed if they exist", {
  # this mock should have all expected datetime columns
  mock_response <- data.frame(
    dt_submitted = as.character(Sys.Date()),
    lrn_dt_started = as.character(Sys.Date()),
    lrn_dt_saved = as.character(Sys.Date())
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response),
    names(mock_response),
    new_datetime(tzone = "UTC")
  )
})

test_that("datetime columns can be read-in as a specific time zone", {
  mock_response <- data.frame(
    dt_submitted = as.character(Sys.Date())
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response, time_zone = Sys.timezone()),
    names(mock_response),
    new_datetime(tzone = Sys.timezone())
  )
})

test_that("list columns are appropriately typed if they exist", {
  # this mock should have all expected list columns
  mock_response <- data.frame(
    lrn_response_json = c("{}", "", ";")
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response),
    names(mock_response),
    list()
  )
})

test_that("all non-explicitly-typed columns are converted to character", {
  mock_response <- data.frame(
    some_variable = factor(1)
  )

  expect_vectors_in_df(
    convert_types_in_responses(mock_response),
    names(mock_response),
    character()
  )
})


# Tests: Required columns -------------------------------------------------

test_that("response tables missing required columns throw informative errors", {
  expect_error(
    ensure_data_in_responses(data.frame(student_id = 1, prompt = 1)),
    "Response table missing required column: class_id"
  )
  expect_error(
    ensure_data_in_responses(data.frame(class_id = 1, prompt = 1)),
    "Response table missing required column: student_id"
  )
  expect_error(
    ensure_data_in_responses(data.frame(class_id = 1, student_id = 1)),
    "Response table missing required column: prompt"
  )
  expect_error(
    ensure_data_in_responses(data.frame(class_id = 1)),
    "Response table missing required columns: student_id, prompt"
  )
})

test_that("responses with a missing class_id are dropped with warning", {
  mock_response <- data.frame(
    class_id = NA,
    student_id = 1,
    prompt = 1
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 0)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 1 row:",
      "\n - missing class_id at row 1"
    )
  )
})

test_that("responses with a missing student_id are dropped with warning", {
  mock_response <- data.frame(
    class_id = 1,
    student_id = NA,
    prompt = 1
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 0)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 1 row:",
      "\n - missing student_id at row 1"
    )
  )
})

test_that("responses with a missing prompt are dropped with warning", {
  mock_response <- data.frame(
    class_id = 1,
    student_id = 1,
    prompt = NA
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 0)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 1 row:",
      "\n - missing prompt at row 1"
    )
  )
})

test_that("responses with multiple missing values have comprehensive warning", {
  mock_response <- data.frame(
    class_id = NA,
    student_id = NA,
    prompt = NA
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 0)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 1 row:",
      "\n - missing class_id at row 1",
      "\n - missing student_id at row 1",
      "\n - missing prompt at row 1"
    )
  )
})

test_that("empty strings are treated like NA when ensuring required columns", {
  mock_response <- data.frame(
    class_id = "",
    student_id = "",
    prompt = ""
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 0)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 1 row:",
      "\n - missing class_id at row 1",
      "\n - missing student_id at row 1",
      "\n - missing prompt at row 1"
    )
  )
})

test_that("multiple dropped responses have a comprehensive warning", {
  mock_response <- data.frame(
    class_id = c(NA, NA, 1, 1),
    student_id = c(NA, 1, NA, 1),
    prompt = c(1, 1, NA, 1)
  )

  expect_nrow(suppressWarnings(ensure_data_in_responses(mock_response)), 1)
  expect_warning(
    ensure_data_in_responses(mock_response),
    paste0(
      "Dropped 3 rows:",
      "\n - missing class_id at rows 1, 2",
      "\n - missing student_id at rows 1, 3",
      "\n - missing prompt at row 3"
    )
  )
})


# Tests: Mapping multiple-choice responses --------------------------------

test_that("cannot map responses without any responses", {
  expect_error(map_response_options(data.frame()))
})

test_that("mapping MC responses adds the lookup table as an attribute", {
  map_response_options(mock_response_looktbl) %>%
    attr("option_value_table") %>%
    expect_is("data.frame")
})

test_that("lookup table cannot be created without type and ref.", {
  expect_warning(
    map_response_options(data.frame(response = 1, lrn_question_reference = 1)),
    "missing required column: lrn_type"
  )

  expect_warning(
    map_response_options(data.frame(response = 1, lrn_type = 1)),
    "missing required column: lrn_question_reference"
  )

  expect_warning(
    map_response_options(data.frame(response = 1)),
    "missing required columns: lrn_type, lrn_question_reference"
  )
})

test_that("the lookup table includes minimum information for mapping", {
  map_response_options(mock_response_looktbl) %>%
    attr("option_value_table") %>%
    expect_named(c("lrn_question_reference", paste0("lrn_option_", 0:2)))
})

test_that("the lookup table only includes multiple choice questions", {
  mcq_item_ids <- mock_response_looktbl %>%
    filter(lrn_type == "mcq") %>%
    .[["lrn_question_reference"]]

  actual <- map_response_options(mock_response_looktbl) %>%
    attr("option_value_table")

  testthat::expect_true(all(actual$lrn_question_reference %in% mcq_item_ids))
})

test_that("the lookup table only has unique entries", {
  expected <- mock_response_looktbl %>%
    distinct(lrn_question_reference, lrn_type) %>%
    filter(lrn_type == "mcq") %>%
    nrow()

  map_response_options(mock_response_looktbl) %>%
    attr("option_value_table") %>%
    expect_nrow(expected)
})

test_that("mapping a non-lookupable item does not change response", {
  map_response_options(mock_response_looktbl[2, ])$response %>%
    expect_identical('["2"]')
})

test_that("mapping an empty response array yields missing value", {
  map_response_options(mock_response_looktbl[4, ])$response %>%
    expect_identical(NA_character_)
})

test_that("mapping a 1 option response yields a length 1 string with value", {
  map_response_options(mock_response_looktbl[1, ])$response %>%
    expect_identical("No")
})

test_that("mapping a 2 option response yields a length 1 delimited string", {
  map_response_options(mock_response_looktbl[3, ])$response %>%
    expect_identical("Yes; No")
})

test_that("mapping responses works with multiple responses in a data.frame", {
  map_response_options(mock_response_looktbl)$response %>%
    expect_identical(c("No", '["2"]', "Yes; No", NA_character_))
})


# Tests: Integration of sub-processes -------------------------------------

test_that("response processing methods do not need to be called in order", {
  order_1 <- mock_responses_integration %>%
    convert_types_in_responses() %>%
    ensure_data_in_responses() %>%
    map_response_options()

  order_2 <- mock_responses_integration %>%
    convert_types_in_responses() %>%
    map_response_options() %>%
    ensure_data_in_responses()

  order_3 <- mock_responses_integration %>%
    ensure_data_in_responses() %>%
    convert_types_in_responses() %>%
    map_response_options()

  order_4 <- mock_responses_integration %>%
    ensure_data_in_responses() %>%
    map_response_options() %>%
    convert_types_in_responses()

  expect_identical(order_1, order_2)
  expect_identical(order_1, order_3)
  expect_identical(order_3, order_4)
})

test_that("general response processing returns a tibble", {
  expect_is(process_responses(mock_responses_integration), "tbl_df")
})

test_that("general response processing method is the sum of its parts", {
  expect_identical(
    mock_responses_integration %>%
      process_responses(),
    mock_responses_integration %>%
      as_tibble() %>%
      ensure_data_in_responses() %>%
      convert_types_in_responses() %>%
      map_response_options()
  )
})

test_that("general response processing allows setting the time zone", {
  expect_identical(
    mock_responses_integration %>%
      process_responses(time_zone = Sys.timezone()),
    mock_responses_integration %>%
      as_tibble() %>%
      ensure_data_in_responses() %>%
      convert_types_in_responses(time_zone = Sys.timezone()) %>%
      map_response_options()
  )
})


# Tests: Processing from files --------------------------------------------

test_that("responses can be processed from a file name", {
  expect_identical(
    process_responses(resp_file_1),
    mock_integration_processed
  )
})

test_that("responses can be processed from a directory path", {
  expect_identical(
    process_responses(class_dir[[1]]),
    mock_integration_processed
  )
})

test_that("multiple response tables can be processed from a directory path", {
  expect_identical(
    process_responses(top_dir),
    bind_rows(mock_responses_integration, mock_responses_integration) %>%
      process_responses()
  )
})

test_that("responses can be processed from a zip file", {
  expect_identical(
    process_responses(zip_file),
    bind_rows(mock_responses_integration, mock_responses_integration) %>%
      process_responses()
  )
})

test_that("responses can be processed from a specific class in a directory", {
  expect_identical(
    process_responses(top_dir, class_id = "class_1"),
    mock_integration_processed
  )
})

test_that("responses can be processed from a multiple classes in a directory", {
  expect_identical(
    process_responses(top_dir, class_id = c("class_1", "class_2")),
    bind_rows(mock_responses_integration, mock_responses_integration) %>%
      process_responses()
  )
})

test_that("responses can be processed from a specific class in a zip file", {
  expect_identical(
    process_responses(zip_file, class_id = "class_1"),
    mock_integration_processed
  )
})


# Tests: Real data --------------------------------------------------------

test_that("processing responses shows no errors with a subset of real data", {
  test_resp <- read.csv("../data/responses.csv")
  expect_error(suppressWarnings(process_responses(test_resp)), NA)
})
