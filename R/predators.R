#' Aggregate predator sightings
#'
#' @param predators Predator data (from raw CSV file)
#'
#' @return Predators aggregated in intervals
#' @export
aggregate_predators <- function(predators) {
  predators %>%
    filter(species != "NULL") %>%
    mutate(year = lubridate::year(UTC_start),
           km = nmi_to_km(nmi)) %>%
    group_by(year, interval, species, UTC_start, lon_mean, lat_mean, nmi, km) %>%
    summarize(count = sum(count_species), .groups = "drop")
}

filter_species <- function(sightings, station_thr) {
  total_stations <- n_distinct(sightings$amlr.station)
  sightings %>%
    group_by(species) %>%
    summarize(n_stations = n_distinct(amlr.station)) %>%
    filter(n_stations >= station_thr * total_stations,
           !str_starts(species, "UN")) %>%
    semi_join(x = sightings, y = ., by = "species")
}

#' Assign sightings to nearest station
#'
#' @param sightings predator sighting data
#' @param stations station data
#' @param max_dist_km maximum spatial tolerance (km)
#' @param max_days maximum temporal tolerance (days)
#'
#' @return predator data associated with nearest station
#' @export
assign_sightings <- function(sightings, stations, max_dist_km, max_days) {
  stopifnot(inherits(sightings, "sf"),
            inherits(stations, "sf"))

  # Assign sightings to stations within year
  assign_group <- function(sightings_group, sightings_key) {
    station_buffers <- stations %>%
      filter(Year == sightings_key$year) %>%
      sf::st_transform(ant_proj()) %>%
      sf::st_buffer(max_dist_km * 1000) %>%
      select(
        amlr.station,
        start.time.UTC
      )
    sightings_group %>%
      sf::st_transform(ant_proj()) %>%
      sf::st_join(station_buffers, left = FALSE) %>%
      mutate(lag_days = abs(as.numeric(UTC_start - start.time.UTC, units = "secs")) / 3600 / 24) %>%
      filter(lag_days <= max_days)
  }

  # Assign sightings across years
  sightings %>%
    group_by(year) %>%
    group_modify(assign_group) %>%
    ungroup() %>%
    sf::st_as_sf()
}

# Normalize species counts by survey effort
normalize_counts <- function(sightings, effort) {
  sightings %>%
    as_tibble() %>%
    group_by(amlr.station, species) %>%
    summarize(count = sum(count_species), .groups = "drop") %>%
    right_join(select(as_tibble(effort), amlr.station, survey_nmi, survey_km),
               by = "amlr.station") %>%
    mutate(count_nmi = count / survey_nmi,
           count_km = nmi_to_km(count_nmi))
}

#' Convert species code to common name
#'
#' @param species_code 4-letter species codes (character vector)
#'
#' @return Species' common names
#' @export
code_to_common <- function(species_code) {
  c(ADPN = "Adélie penguin",
    ANFU = "Southern fulmar",
    ANPT = "Antarctic petrel",
    ANPR = "Antarctic prion",
    ANSH = "Antarctic shag",
    ANTE = "Antarctic tern",
    BBAL = "Black-browed albatross",
    BLPT = "Blue petrel",
    CAPT = "Cape petrel",
    CHPN = "Chinstrap penguin",
    CODP = "Common diving petrel",
    CRSE = "Crabeater seal",
    ELSE = "Elephant seal",
    EMPN = "Emperor penguin",
    FUSE = "Antarctic fur seal",
    GEPN = "Gentoo penguin",
    HUWH = "Humpback whale",
    KEGU = "Kelp gull",
    KEPT = "Kerguelen petrel",
    KIWH = "Killer whale",
    LESE = "Leopard seal",
    MIWH = "Minke whale",
    NGPT = "Northern giant petrel",
    PFSB = "Pale-faced sheathbill",
    ROSE = "Ross seal",
    SBWH = "Bottlenose whale",
    SGPT = "Southern giant petrel",
    SNPT = "Snow petrel",
    SPSK = "South polar skua",
    WESE = "Weddell seal")[species_code]
}

#' Convert species code to scientific name
#'
#' @param species_code 4-letter species codes (character vector)
#'
#' @return Species' scientific names
#' @export
code_to_scientific <- function(species_code) {
  c(ADPN = "Pygoscelis adeliae",
    ANFU = "Fulmarus glacialoides",
    ANPT = "Thalassoica antarctica",
    ANSH = "Leucocarbo bransfieldensis",
    ANTE = "Sterna vittata",
    BLPT = "Halobaena caerulea ",
    CAPT = "Daption capense",
    CRSE = "Lobodon carcinophagus",
    ELSE = "Mirounga leonina",
    EMPN = "Aptenodytes forsteri",
    FUSE = "Arctocephalus gazella",
    GEPN = "Pygoscelis papua",
    KEGU = "Larus dominicanus",
    KIWH = "Orcinus orca",
    LESE = "Hydrurga leptonyx",
    MIWH = "Balaenoptera bonaerensis",
    PFSB = "Chionis albus",
    ROSE = "Ommatophoca rossii",
    SBWH = "Hyperoodon planifrons",
    SGPT = "Macronectes giganteus",
    SNPT = "Pagodroma nivea",
    WESE = "Leptonychotes weddellii")[species_code]
}
