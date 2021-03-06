#' Retrieve data from a data cache.
#' 
#' This function maintains a data cache. When called, it will see if a "fresh"
#' data file is available. If not (i.e. the cache is "stale"), \code{FUN} will
#' be called to retreive more up-to-date data. On systems supporting forking
#' (e.g. Linux and Mac OS X), the refreshing of data will occur in the background
#' and the most "fresh" data will be returned until that background process
#' completes.
#' 
#' The \code{FUN} parameter is required. This function should return a named
#' \code{\link{list}} of objects. These objects will be assigned to the
#' given environment (the calling environment by default).
#' 
#' There are a number of frequencies available to determine when a cached file
#' becomes stale including: \code{\link{hourly}}, \code{\link{daily}},
#' \code{\link{weekly}}, \code{\link{monthly}}, \code{\link{yearly}},
#' \code{\link{nMinutes}}, \code{\link{nHours}}, and \code{\link{nDays}}.
#' 
#' It is possible to define custom frequencies. Each frequency function takes
#' one parameter, \code{timestamp}, which has a class type of \code{POSIXct},
#' and returns a \code{logical} value where \code{TRUE} indicates the cache
#' created at \code{timestamp} is stale.
#' 
#' See the Vignette (\code{vignette('DataCache')}) or demo
#' (\code{demo('WeatherCache')}) for more information.
#' 
#' @param FUN the function used to laod the data.
#' @param frequency how frequently should the cache expire.
#' @param cache.dir the directory containing the cached data files.
#' @param cache.name name of the cache.
#' @param envir the enviroment into which data will be loaded.
#' @param wait should the function wait until stale data is refreshed.
#' @param ... other parameters passed to \code{FUN}.
#' @seealso \link{daily}, \link{hourly}, \link{weekly}, \link{monthly}, 
#'   \link{yearly}, \link{nMinutes}, \link{nHours}, \link{nDays}
#' @examples
#' \dontrun{
#' library('weatherData')
#' loadWeatherData <- function(station_id='ALB') {
#' 		results <- list(getDetailedWeather(station_id, Sys.Date()))
#' 		names(results) <- paste0('weather.', station_id)
#' 		return(results)
#' }
#' data.cache(loadWeatherData)
#' head(weather.ALB)
#' }
#' @export
data.cache <- function(FUN,
						  frequency=daily,
						  cache.dir='cache',
						  cache.name='Cache',
						  envir=parent.frame(),
						  wait=FALSE,
						  ...) {
	if(missing(FUN)) {
		stop('FUN is missing! This parameter defines a function to load data.')
	}
	
	cache.date <- Sys.time()
	return.date <- cache.date
	if(!file.exists(cache.dir)) {
		dir.create(cache.dir, recursive=TRUE, showWarnings=FALSE)
		cache.dir <- normalizePath(cache.dir)
	}
	cinfo <- cache.info(cache.dir=cache.dir, cache.name=cache.name, stale=NULL)
	new.cache.file <- paste0(cache.dir, '/', cache.name, cache.date, '.rda')
	
	if(nrow(cinfo) > 0 & Sys.info()['sysname'] != 'Windows' & !wait) {
		if(frequency(cinfo[1,]$created)) { # Check to see if the cache is stale
			lock.file <- paste0(cache.dir, '/', cache.name, '.lck')
			if(!file.exists(lock.file)) {
				now <- Sys.time()
				save(now, file=lock.file)
				# This is a bit of hack. Not sure when the estranged parameter was added
				# 				params <- formals(parallel:::mcfork)
				# 				if('estranged' %in% names(params)) {
				p <- parallel:::mcfork(estranged=TRUE)	
				# 				} else {
				# 					p <- parallel:::mcfork()
				# 				}
				# 				p <- mcfork(estranged=TRUE) # Using interal copy of function
				if(inherits(p, "masterProcess")) {
					sink(file=paste0(cache.dir, '/', cache.name, cache.date, '.log'), append=TRUE)
					print(paste0('Loading data at ', Sys.time()))
					tryCatch({
						thedata <- FUN(...)
						if(class(thedata) == 'list') {
							save(list=ls(thedata), envir=as.environment(thedata), 
								 file=new.cache.file)
						} else {
							save(thedata, file=new.cache.file)
						}							
						sink()
					},
					error = function(e) {
						print(e)
					},
					finally = {
						unlink(lock.file)
						parallel:::mcexit()
						# mcexit() # Using interal copy of of function
					}
					)
					invisible(new.cache.file)
				}
			} else {
				finfo <- file.info(lock.file)
				message(paste0('Data is being loaded by another process. ',
							   'The process has been running for ',
							   difftime(Sys.time(), finfo$ctime, units='secs'),
							   ' seconds. If this is an error delete ', lock.file))
			}
			message('Loading more recent data, returning lastest available.')
		}
		load(paste0(cache.dir, '/', cinfo[1,]$file), envir=envir)
		return.date <- cinfo[1,]$created
	} else {
		if(Sys.info()['sysname'] == 'Windows' & nrow(cinfo) == 0) {
			message('Background processing is not supported on Windows. Loading new data...')
		} else if(wait) {
			message('Loading new data...')
		} else {
			message('No cached data found. Loading intial data...')
		}
		sink(file=paste0(cache.dir, '/', cache.name, cache.date, '.log'), append=TRUE)
		print(paste0('Loading data at ', Sys.time()))
		thedata <- FUN(...)
		if(class(thedata) == 'list') {
			save(list=ls(thedata), envir=as.environment(thedata), 
				 file=new.cache.file)
		} else {
			save(thedata, file=new.cache.file)
		}
		sink()
		load(new.cache.file, envir=envir)			
	}
	
	invisible(return.date)
}

#' Returns information about the cache.
#' 
#' Utility function that returns meta data about the given cache.
#' 
#' @param cache.dir the directory containing the cached files.
#' @param cache.name name of the cache.
#' @param units the units to use for calculate the age of the cache file.
#' @param stale a vector of frequencies to test whether each cache file
#'        is stale according to that metric. If \code{NULL}, no info is provided.
#' @return a data frame with three columns: the cached file name, the date/time
#'         created, and the age in the specified units (default is minutes).
#' @export
cache.info <- function(cache.dir = 'cache', 
					   cache.name = 'Cache', 
					   units = 'mins', 
					   stale = c('hourly' = hourly, 
					   		  'daily' = daily, 
					   		  'weekly' = weekly,
					   		  'monthly' = monthly,
					   		  'yearly' = yearly)) {
	if(!is.null(stale) & any(names(stale) == '')) {
		stop("stale must be a named vector (e.g. stale=c(hourly=hourly)")
	}
	results <- data.frame()
	if(file.exists(cache.dir)) {
		cache.files <- list.files(path=cache.dir, pattern = paste0("^", cache.name,"[0-9]{4}-[0-9]{2}-[0-9]{2}"))
		cache.files <- cache.files[grep('*.rda$', cache.files)] # Get only .rda files
		if(length(cache.files) > 0) {
			timestamps <- substr(cache.files, 
								 nchar(cache.name) + 1,
								 sapply(cache.files, nchar) - 4)
			results <- data.frame(file=cache.files,
								  created=as.POSIXct(timestamps),
								  age=as.numeric(difftime(Sys.time(), timestamps, units=units)))
			names(results)[3] <- paste0('age_', units)
			if(!is.null(stale)) {
				for(i in seq_along(stale)) {
					results[,paste0(names(stale)[i], '_stale')] <- stale[[i]](timestamps)
				}
			}
			results <- results[order(results$created, decreasing=TRUE),]
		}
	}
	attr(results, 'cache.dir') <- cache.dir
	return(results)
}
