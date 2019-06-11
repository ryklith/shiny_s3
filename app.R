library(shiny)
library(aws.s3)
library(digest)
library(RPostgres)
library(shinyjs)
library(tools)

s3BucketName <- "<your-bucket-name>"
Sys.setenv("AWS_ACCESS_KEY_ID" = "asdfasdfasdf",
           "AWS_SECRET_ACCESS_KEY" = "asdfasdfasdf",
           "AWS_DEFAULT_REGION" = "eu-central-1")

# get a formatted string of the timestamp (exclude colons as they are invalid
# characters in Windows filenames)
get_time_human <- function() {
  format(Sys.time(), "%Y%m%d-%H%M%OS")
}

getDbConnection <- function() {
  conn <- dbConnect(drv = RPostgres::Postgres(),
                    dbname = Sys.getenv("PE_DEV_DB_NAME"),
                    host = Sys.getenv("PE_DEV_DB_HOST"),
                    user = Sys.getenv("PE_DEV_DB_USER"),
                    password = Sys.getenv("PE_DEV_DB_PASSWORD"))
}

addFileToDb <- function(inFile, file_name, owner_email) {
  
  # Schema:
  # CREATE TABLE user_files
  # (
  #   id                SERIAL NOT NULL,
  #   url               TEXT,
  #   type              TEXT,
  #   display_file_name TEXT,
  #   comment           TEXT,
  #   upload_timestamp  TIMESTAMP DEFAULT now(),
  #   owner_email       TEXT
  # );
  
  conn <- getDbConnection()
  
  sql <- sprintf(
    "INSERT INTO %s (url, type, display_file_name, owner_email) VALUES (\'%s\', \'%s\',  \'%s\', \'%s\');",
    "user_files",
    file_name,
    inFile$type,
    inFile$name,
    owner_email
  )

  dbSendQuery(conn, sql)  
}

getDb <- function() {
  conn <- getDbConnection()
}

uploadFile <- function(inFile) {
  print("Uploading file...")
  file_name <- paste0(
    paste(
      get_time_human(),
      digest(inFile, algo = "md5"),
      sep = "_"
    ),
    ".",
    file_ext(inFile$name)
  )
  addFileToDb(inFile, file_name, 'tom@sample.com')
  
  # Upload the file to S3
  put_object(file = inFile$datapath, object = file_name, bucket = s3BucketName)
  print("Upload to S3 successful.")
}

loadData <- function() {
  con <- getDbConnection()
  
  sql <- sprintf(
    "SELECT * FROM %s;",
    "user_files"
  )
  
  rows <- dbGetQuery(con, sql)
}


getMetadata <- function(id) {
  loadData()[id,]
}

temp <- function() {
  browser()
  return("application/zip")
}

# Shiny app with 3 fields that the user can submit data for
shinyApp(
  ui = fluidPage(
    h1("List of files in bucket:"),
    # actionButton("refresh", "Refresh"),
    DT::dataTableOutput("files", width = 300),
    downloadButton("downloadSelected", "Download selected file"),
    tags$hr(),
    h1("Upload another file:"),
    fileInput("uploadFile", 
              NULL, 
              multiple = FALSE, 
              accept = NULL,
              width = NULL, 
              buttonLabel = "Select file...",
              placeholder = "No file selected")
  ),
  
  server = function(input, output, session) {
    
    observeEvent(input$uploadFile, {
      inFile <- input$uploadFile
      if (is.null(inFile)) {
        return (NULL)
      }
      uploadFile(inFile)
      refreshListener[["updateCounter"]] <- refreshListener$updateCounter + 1
    })
    
    output$downloadSelected <- downloadHandler(
      filename = function(){
        selectedFileMetadata()$display_file_name
      },
      content = function(fname) {
        url <- selectedFileMetadata()$url
        save_object(url, s3BucketName, file=fname)
      }
    )
    
    # Show the files in the bucket
    output$files <- DT::renderDT(
      DT::datatable(df(),
                    selection='single')
    )
    
    # needed to recognize a change for auto-refresh
    refreshListener <- reactiveValues(updateCounter = 0)
    df <- eventReactive(list(refreshListener$updateCounter), {
      loadData()
    }, ignoreNULL=FALSE)
    
    # convenience
    selectedFileMetadata <- eventReactive(input$files_rows_selected, {
      getMetadata(input$files_rows_selected)
    })
  }
)
