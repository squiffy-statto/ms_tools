


# Function to wrap RMD code blocks in <pre><code> tags

knitr::knit_hooks$set(
  
  source = function(x, options) {

    if (!is.null(options$hilang)) {
    
      # Code tags for open and close
      code_open  = paste0("<pre><code class=\"language-", options$hilang ,"\">")
      code_close = "</code></pre>"
    
      # Code body from file location or direct text
      if (!is.null(options$from_file) && options$from_file) {
        code_body <- readLines(file.path(x))   
      } else {
        code_body <- x
      }
    
      # Create html for code block
      knitr::asis_output(
        htmltools::htmlPreserve(
          stringr::str_c(code_open, paste(code_body, collapse="\n"), code_close)
        )
      )
    } else {
      
    # Use default engine settings for highlighting  
    stringr::str_c("\n```", tolower(options$engine), "\n", paste(x, collapse = "\n", "\n```\n"))
  
    }
})
