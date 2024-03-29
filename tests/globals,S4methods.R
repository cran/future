source("incl/start.R")
library(methods)

message("*** Globals - S4 methods ...")

setGeneric("my_fcn", function(x) standardGeneric("my_fcn"))
setMethod("my_fcn", signature(x = "numeric"), function(x) { -x })
org_my_fcn <- my_fcn

truth <- my_fcn(3)

for (strategy in supportedStrategies()) {
  message("Type of future: ", strategy)
  plan(strategy)

  ## Assert that S4 generic function 'my_fcn()' is exported
  f <- future({ my_fcn }, lazy = TRUE)
  rm(list = "my_fcn")
  v <- value(f)
  print(v)
  stopifnot(
    is.function(v),
    inherits(v, class(org_my_fcn)[1])
  )
  my_fcn <- org_my_fcn
  
  ## FIXME:
  ## Just like S3 methods, S4 methods are not picked up
  ## https://github.com/HenrikBengtsson/future/issues/615
  f <- future({ my_fcn(3) }, lazy = TRUE)
  rm(list = "my_fcn")
  v <- tryCatch(value(f), error = identity)
  print(v)
  if (isTRUE(as.logical(Sys.getenv("R_CHECK_IDEAL")))) {
    if (getOption("future.globals.keepWhere", TRUE)) {
      stopifnot(identical(v, truth))
    } else {
      stopifnot(inherits(v, "error"))
    }
  } else if (isTRUE(getOption("future.globals.keepWhere", FALSE))) {
    stopifnot(identical(v, truth))
  } else {
    if (strategy %in% c("sequential", "multicore")) {
      stopifnot(inherits(v, "error"))
    } else {
      stopifnot(identical(v, truth))
    }
  }
  my_fcn <- org_my_fcn
}

message("*** Globals - S4 methods ... DONE")

source("incl/end.R")
