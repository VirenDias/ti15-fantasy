library(httr)

gql_query <- function(
    query, 
    ..., 
    token = NULL,
    variables = NULL, 
    operation_name = NULL, 
    url = NULL
) {
  pbody <- list(
    query = query, 
    variables = variables, 
    operation_name = operation_name
  )
  if(is.null(token)){
    res <- POST(url, body = pbody, encode="json", ...)
  } else {
    auth_header <- paste("bearer", token)
    res <- POST(
      url, 
      body = pbody, 
      encode="json", 
      add_headers(Authorization=auth_header), 
      ...
    )
  }
  res <- content(res, as = "parsed", encoding = "UTF-8")
}