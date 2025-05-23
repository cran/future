% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/backend_api-11.MulticoreFutureBackend-class.R
\name{usedCores}
\alias{usedCores}
\title{Get number of cores currently used}
\usage{
usedCores()
}
\value{
A non-negative integer.
}
\description{
Get number of children (and don't count the current process)
used by the current \R session.  The number of children
is the total number of subprocesses launched by this
process that are still running and whose values have yet
not been collected.
}
\keyword{internal}
