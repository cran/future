% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/protected_api-FutureCondition-class.R,
%   R/protected_api-journal.R
\name{FutureCondition}
\alias{FutureCondition}
\alias{FutureMessage}
\alias{FutureWarning}
\alias{FutureError}
\alias{RngFutureCondition}
\alias{RngFutureWarning}
\alias{RngFutureError}
\alias{UnexpectedFutureResultError}
\alias{GlobalEnvMisuseFutureCondition}
\alias{GlobalEnvMisuseFutureWarning}
\alias{GlobalEnvMisuseFutureError}
\alias{ConnectionMisuseFutureCondition}
\alias{ConnectionMisuseFutureWarning}
\alias{ConnectionMisuseFutureError}
\alias{DeviceMisuseFutureCondition}
\alias{DeviceMisuseFutureWarning}
\alias{DeviceMisuseFutureError}
\alias{FutureLaunchError}
\alias{FutureInterruptError}
\alias{FutureCanceledError}
\alias{FutureDroppedError}
\alias{FutureJournalCondition}
\title{A condition (message, warning, or error) that occurred while orchestrating a future}
\usage{
FutureCondition(message, call = NULL, uuid = future[["uuid"]], future = NULL)

FutureMessage(message, call = NULL, uuid = future[["uuid"]], future = NULL)

FutureWarning(message, call = NULL, uuid = future[["uuid"]], future = NULL)

FutureError(message, call = NULL, uuid = future[["uuid"]], future = NULL)

RngFutureCondition(
  message = NULL,
  call = NULL,
  uuid = future[["uuid"]],
  future = NULL
)

RngFutureWarning(...)

RngFutureError(...)

UnexpectedFutureResultError(future, hint = NULL)

GlobalEnvMisuseFutureCondition(
  message = NULL,
  call = NULL,
  differences = NULL,
  uuid = future[["uuid"]],
  future = NULL
)

GlobalEnvMisuseFutureWarning(...)

GlobalEnvMisuseFutureError(...)

ConnectionMisuseFutureCondition(
  message = NULL,
  call = NULL,
  differences = NULL,
  uuid = future[["uuid"]],
  future = NULL
)

ConnectionMisuseFutureWarning(...)

ConnectionMisuseFutureError(...)

DeviceMisuseFutureCondition(
  message = NULL,
  call = NULL,
  differences = NULL,
  uuid = future[["uuid"]],
  future = NULL
)

DeviceMisuseFutureWarning(...)

DeviceMisuseFutureError(...)

FutureLaunchError(..., future = NULL)

FutureInterruptError(..., future = NULL)

FutureCanceledError(..., future = NULL)

FutureDroppedError(..., future = NULL)

FutureJournalCondition(
  message,
  journal,
  call = NULL,
  uuid = future[["uuid"]],
  future = NULL
)
}
\arguments{
\item{message}{A message condition.}

\item{call}{The call stack that led up to the condition.}

\item{uuid}{A universally unique identifier for the future associated with
this FutureCondition.}

\item{future}{The \link{Future} involved.}

\item{hint}{(optional) A string with a suggestion on what might be wrong.}
}
\value{
An object of class FutureCondition which inherits from class
\link[base:conditions]{condition} and FutureMessage, FutureWarning,
and FutureError all inherits from FutureCondition.
Moreover, a FutureError inherits from \link[base:conditions]{error},
a FutureWarning from \link[base:conditions]{warning}, and
a FutureMessage from \link[base:conditions]{message}.
}
\description{
While \emph{orchestrating} (creating, launching, querying, collection)
futures, unexpected run-time errors (and other types of conditions) may
occur.  Such conditions are coerced to a corresponding FutureCondition
class to help distinguish them from conditions that occur due to the
\emph{evaluation} of the future.
}
\keyword{internal}
