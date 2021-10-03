##### create an in-memory sqlite database using DBI #####
# https://medium.com/@skyetetra/pretending-to-have-a-sql-database-with-rstudio-e80d9a1338b1

library(DBI)
library(jsonlite)
library(tidyverse)

con <- dbConnect(RSQLite::SQLite(), dbname = ":memory:")

path_data <- 'data/raw/'

### list certain types of files desired
## this JSON is flat
stream_files <- list.files(path = path_data, 
                           pattern = 'StreamingHistory' , 
                           full.names=TRUE)

## this JSON is nested
playlist_files  <- list.files(path = path_data, 
                              pattern = 'Playlist' , 
                              full.names=TRUE)

##### convert flat JSON to CSV #####
fx_stackJSON <- function(file_list){
    
    out <- lapply(file_list, FUN = function(x){
        
        mid = fromJSON(x[[1]])
        
    }) %>% bind_rows(.)
    
    return(out)
    
}

# jsonlite::parse_json(<input_data>)
stream_data <- fx_stackJSON(stream_files)
## each row in this data frame has a list nested in the column "items"
playlist_data <- fromJSON(playlist_files, flatten=TRUE)

names(stream_data)
names(playlist_data)

## grab just the playlist names
playlist_names <- playlist_data$playlists$name

## extract the nested list as a data.frame, assign the playlist name
combined_playlists <- lapply(seq(1, length(playlist_data$playlists$items)), FUN = function(playlist_index){
    
    ## for each data.frame, add a column that matches the index of playlist_names
    playlist <- playlist_data$playlists$items[[playlist_index]]
    playlist$playlist_name <- playlist_names[playlist_index]
    
    ## cleanup column names
    playlist <- playlist %>% rename(trackName = track.trackName, 
                                    artistName = track.artistName,
                                    albumName = track.albumName, 
                                    trackUri=track.trackUri)
        
    return(playlist)
    
    ## return a single data.frame
}) %>% bind_rows(.)

##### load data to database #####
dbWriteTable(con, "StreamingHistory", stream_data)
dbWriteTable(con, "Playlists", combined_playlists)

##### run queries with DBI #####
dbGetQuery(con, "SELECT * FROM StreamingHistory LIMIT 10")
dbGetQuery(con, "SELECT * FROM Playlists LIMIT 10")

##### run queries with dbplyr #####
# https://datacarpentry.org/R-ecology-lesson/05-r-and-databases.html

##### explore spotifyR #####
# https://towardsdatascience.com/explore-your-activity-on-spotify-with-r-and-spotifyr-how-to-analyze-and-visualize-your-stream-dee41cb63526

##### most played songs - StreamingHistory ######
stream_data %>% 
    group_by(artistName, trackName) %>% 
    count %>% 
    arrange(desc(n)) %>% 
    head(10)

## in SQL
head(dbGetQuery(con, "SELECT artistName, trackName, COUNT(trackName) as number
           FROM StreamingHistory
           GROUP BY trackName
           ORDER BY number DESC"), 10)

##### most played artists #####
stream_data %>% 
    group_by(artistName) %>% 
    count %>% 
    arrange(desc(n)) %>% 
    head(10) 

## in SQL
head(dbGetQuery(con, 'SELECT artistName, COUNT(artistName) as count
            FROM StreamingHistory
           GROUP BY artistName
           ORDER BY count DESC'), 10)


##### most songs in one day #####
stream_data %>% mutate(date = str_sub(endTime, 1, 10)) %>% 
    group_by(date) %>% 
    count %>% 
    arrange(desc(n)) %>% 
    head(10)

## this is SQLITE syntax, other SQL might use "LEFT(endTime, 10)"
# temporarily create a column named date, use that to group by...COUNT doesn't work on aliases I guess
head(dbGetQuery(con, 'SELECT substr(endTime, 1, 10) AS date, COUNT(endTime) AS count
                 FROM StreamingHistory
                 GROUP BY date
                 ORDER BY count DESC'))
 
##### compare most played artists this year to Summer Rewind playlists of 2019 and 2020 #####

##### artist diversity ######

##### song diversity #####

