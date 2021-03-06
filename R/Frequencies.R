#' Refresh the cache now.
#' 
#' This function will always return TRUE therefore causing the cache to always
#' be refreshed.
#' 
#' @param timestamp the timestamp to test whether the cache is stale.
#' @return Always returns TRUE.
#' @export 
now <- function(timestamp) {
	return(TRUE)
}

#' Refresh data hourly.
#' 
#' This function will return TRUE when the data cache is stale and the data should
#' be refreshed. Essentially this will return TRUE after the top of each hour.
#' For example, if the last cache was created at 9:59 and then called again at
#' 10:01, this function will return TRUE. If you wish to refresh every, say, 60
#' minutes, use the \code{\link{nMinutes}} function.
#' 
#' @param timestamp the timestamp to test whether the cache is stale.
#' @return Returns TRUE if the the cache is stale.
#' @export
hourly <- function(timestamp) {
	now <- Sys.time()
	return(hour(now) > hour(timestamp) |
		   day(now) > day(timestamp) | 
		   month(now) > month(timestamp) | 
		   year(now) > year(timestamp))
}

#' Refresh data yearly.
#' 
#' Data becomes stale yearly.
#' 
#' @inheritParams hourly
#' @export
yearly <- function(timestamp) {
	now <- Sys.time()
	return(year(now) > year(timestamp))
}

#' Refresh data monthly.
#' 
#' Data becomes stale monthly.
#' 
#' @inheritParams hourly
#' @export
monthly <- function(timestamp) {
	now <- Sys.time()
	return(month(now) > month(timestamp) | 
		   year(now) > year(timestamp))
}

#' Refresh data weekly.
#' 
#' This function will return TRUE when the data cache is stale and the data should
#' be refreshed.
#' 
#' @inheritParams hourly
#' @export
weekly <- function(timestamp) {
	now <- Sys.time()
	return(week(now) > week(timestamp) |
		   year(now) > year(timestamp))
}

#' Refresh data daily.
#' 
#' This function will return TRUE when the data cache is stale and the data should
#' be refreshed.
#' 
#' @inheritParams hourly
#' @export
daily <- function(timestamp) {
	now <- Sys.time()
	return(day(now) > day(timestamp) | 
		   month(now) > month(timestamp) | 
		   year(now) > year(timestamp))
}

#' Refresh every n days.
#' 
#' Data becomes stale after n days.
#' 
#' @param days number of days (minimally) between updates.
#' @export
nDays <- function(days) {
	return(nMintues(24 * 60 * days))
}

#' Refresh every n hours.
#' 
#' Data becomes stale after n hours.
#' 
#' @param hours number of hours (minimally) between updates.
#' @export
nHours <- function(hours) {
	return(nMinutes(60 * hours))
}

#' Refresh every n minutes.
#'
#' Data becomes stale after n minutes.
#' 
#' @param minutes number of minutes (minimally) between updates.
#' @export
nMinutes <- function(minutes) {
	fun <- function(timestamp) {
		return(difftime(Sys.time(), timestamp, units='mins') > minutes)
	}
	return(fun)
}
