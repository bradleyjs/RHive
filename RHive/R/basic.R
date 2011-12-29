# Copyright 2011 NexR
#    
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


rhive.basic.mode <- function(tablename, col) {

	if(missing(tablename))
		stop("missing tablename")
	if(missing(col))
		stop("missing colname")

	hql <- sprintf("SELECT %s , COUNT(1) max FROM %s GROUP BY %s ORDER BY max DESC LIMIT 1", col, tablename, col)
	
	rhive.query(hql)

}

rhive.basic.range <- function(tablename, col) {

	if(missing(tablename))
		stop("missing tablename")
	if(missing(col))
		stop("missing colname")

    hql <- sprintf("SELECT MIN(%s) min, MAX(%s) max FROM %s", col, col, tablename)
	
	rhive.query(hql)

}

rhive.basic.merge <- function(x, y, by.x, by.y) {

	if(missing(x))
		stop("missing parameter(first tablename)")
	if(missing(y))
		stop("missing parameter(second tablename)")

	xcols <- rhive.desc.table(x)[,'col_name']
	ycols <- rhive.desc.table(y)[,'col_name']
	
	joinkeys <- NULL
	yjoinkeys <- NULL
	unioncols <- c(xcols,ycols)
	
	if(missing(by.x) && missing(by.y)) {
	
		joinkeys <- intersect(xcols, ycols)
		yjoinkeys <- joinkeys
		
  	}else if(missing(by.y)) {
  		
  		joinkeys <- by.x
  		yjoinkeys <- joinkeys
  		
  	}else if(missing(by.x)) {
  		
  		joinkeys <- by.y
  		yjoinkeys <- joinkeys
  	
  	}else {
  	
  		joinkeys <- by.x
  		yjoinkeys <- by.y
  	
  	}
  	
  	unioncols <- c(setdiff(xcols, joinkeys), setdiff(ycols, yjoinkeys))
  	
  	sharedcols <- intersect(setdiff(xcols, joinkeys),setdiff(ycols, yjoinkeys))
  	if(length(sharedcols) > 0) {
  		unioncols <- c(setdiff(unioncols, sharedcols), paste("x.",sharedcols,sep=""))
  	}
  		
	hql <- paste("SELECT ", paste("x.", joinkeys, sep="", collapse=","), ",", paste(unioncols, collapse=","), " FROM ", x, " x JOIN ", y, " y ", sep="")
	
	if(!is.null(joinkeys)) {
		where <- ""
		for (i in 1:length(joinkeys)) {  
	 
	  		if (i==1) {
	  			where <- paste("ON x.", joinkeys[i], " = y.", yjoinkeys[i], sep="")  
	  		} else { 
	  			where <- paste(where, paste(" and x.", joinkeys[i], " = y.", yjoinkeys[i], sep=""))
	  	    }
	  	}
	  	
	  	hql <- paste(hql, where)
  	}
  	
  	print(hql)
  	
  	rhive.query(hql)
}

rhive.basic.xtabs <- function(x, cols, tablename) {

	if(missing(cols))
		stop("missing colnames")
	if(missing(tablename))
		stop("missing tablename")

	gcols <- .generateColumnString(cols)

	if(missing(x)) {
		hql <- sprintf("SELECT %s, COUNT(1) x_count FROM %s GROUP BY %s", gcols, tablename, gcols)
	}else {
		hql <- sprintf("SELECT %s, SUM(%s) %s FROM %s GROUP BY %s", gcols, x, x, tablename, gcols)
	}
	
	pivotresult <- rhive.query(hql)
	
	fcols <- .generateColumnString(cols,sep="+")
	formula <- ""
	
	if(missing(x)) {
		formula <- sprintf("%s ~ %s","x_count",fcols)
	}else {
		formula <- sprintf("%s ~ %s",x,fcols)
	}
	
	return(xtabs(formula, pivotresult)) 

}

rhive.basic.cut <- function(tablename, col, breaks, summary = FALSE) {
	
	if(missing(col))
		stop("missing colname")
	if(missing(tablename))
		stop("missing tablename")
	if(missing(breaks))
		stop("missing breaks")
	
	if(summary) {
		hql <- sprintf("SELECT rkey(%s,'%s'), COUNT(%s) FROM %s GROUP BY rkey(%s,'%s')",col,breaks,col,tablename,col,breaks)
		
		tmp <- rhive.query(hql)
		
		result <- unlist(tmp['X_c1'])
		names(result) <- unlist(tmp['X_c0'])
		
		return(result)
	}else {
	
		tmpTable <- paste("cut_", tablename,as.integer(Sys.time()),sep="")
		hql <- ""
	    xcols <- rhive.desc.table(tablename)[,'col_name']
		cols <- setdiff(xcols, col)
		
		if(length(cols) > 0) {
			hql <- sprintf("CREATE TABLE %s AS SELECT %s, rkey(%s,'%s') %s FROM %s",tmpTable,paste(cols, collapse=","),col,breaks,col, tablename)
		}else {
			hql <- sprintf("CREATE TABLE %s AS SELECT rkey(%s,'%s') %s FROM %s",tmpTable, col,breaks,col,tablename)
		}
		
		rhive.query(hql)
	
		return(tmpTable)
	}
	
}

rhive.basic.by <- function(tablename, cols, INDICES, FUN) {

	if(missing(cols))
		stop("missing colname")
	if(missing(tablename))
		stop("missing tablename")
	if(missing(INDICES))
		stop("missing INDICES")
	if(missing(FUN))
		stop("missing FUN")

    colnames <- paste(FUN, "(", cols, ")", sep="", collapse=",")
	groups <- paste(INDICES, collapse=",")

	hql <- sprintf("SELECT %s FROM %s GROUP BY %s",colnames,tablename,groups)
	
	rhive.query(hql)
}

.generateColumnString <- function(columns,sep=",",excludes) {

    colindex <- 0
    cols <- ""

    for(element in columns) {
         cols <- paste(cols,element,sep="")    
         if(colindex < length(columns) - 1) {
         	cols <- paste(cols, sep ,sep="")
         }
         colindex <- colindex + 1
    }

    return(cols)
}