# Code sample for how to upload and download from AWS S3 with R Shiny
This is a small shiny app with an upload button and a list of files in a bucket. Each file can be downloaded through the browser. There is a database that keeps track of file metadata.

# Getting Started
- Set up a small Postgres table and store the connection data in environment variables
- Set up an S3 bucket and note down your access keys
- install.packages() for all dependencies
- Run app from RStudio
