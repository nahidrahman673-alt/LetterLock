# Wikidata queries for the word lists

Run on QLever's copy of Wikidata (https://qlever.dev/api/wikidata, much faster than
query.wikidata.org for lists this size), saving CSV:

```bash
curl -sS -G https://qlever.dev/api/wikidata -H 'Accept: text/csv' \
  --data-urlencode "query=$PREFIXES $QUERY" -o result.csv
```

Then build with `python3 -I Tools/make_word_lists.py names|wikidata ...` (see that script).
Wikidata is CC0, so no credit is needed.

"Sitelinks" is how many language Wikipedias have a page on it: a good sign of how well known it is.
Names are taken in English, or in Wikidata's "mul" (all languages) label, which most people now use.

## Prefixes

```sparql
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX wikibase: <http://wikiba.se/ontology#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
```

## First names (names_male.csv, names_female.csv, names_unisex.csv)

`$TYPE` is wd:Q12308941 (male given name), wd:Q11879590 (female) or wd:Q3409032 (unisex).

```sparql
SELECT DISTINCT ?nLabel WHERE {
  ?n wdt:P31 $TYPE . ?n rdfs:label ?nLabel .
  FILTER(LANG(?nLabel) = "en" || LANG(?nLabel) = "mul")
}
```

## The shape of the other queries

`$FIND` picks the items and their `?sitelinks`; the rest fetches the name and other names.

```sparql
SELECT ?item ?sitelinks ?label (GROUP_CONCAT(DISTINCT ?alias; SEPARATOR="|") AS ?aliases) WHERE {
  { SELECT DISTINCT ?item ?sitelinks WHERE { $FIND } }
  OPTIONAL { ?item rdfs:label ?en . FILTER(LANG(?en) = "en") }
  OPTIONAL { ?item rdfs:label ?mul . FILTER(LANG(?mul) = "mul") }
  BIND(COALESCE(?en, ?mul) AS ?label) FILTER(BOUND(?label))
  OPTIONAL { ?item skos:altLabel ?alias . FILTER(LANG(?alias) = "en" || LANG(?alias) = "mul") }
} GROUP BY ?item ?sitelinks ?label
```

### Movies/Series

Films (film, animated film, film series), 10+ sitelinks:

```sparql
VALUES ?type { wd:Q11424 wd:Q202866 wd:Q24856 }
?item wdt:P31 ?type . ?item wikibase:sitelinks ?sitelinks . FILTER(?sitelinks >= 10)
```

Series (television series, animated television series, anime television series, miniseries), 6+:

```sparql
VALUES ?type { wd:Q5398426 wd:Q117467246 wd:Q63952888 wd:Q1259759 }
?item wdt:P31 ?type . ?item wikibase:sitelinks ?sitelinks . FILTER(?sitelinks >= 6)
```

### Celebrity

Entertainers and sports people born 1900 or later, 20+ sitelinks. Jobs: actor, film actor, TV actor,
singer, musician, rapper, singer-songwriter, footballer, basketball player, tennis player, boxer, model,
comedian, TV presenter, YouTuber, film director, racing driver, cricketer, American football player,
MMA fighter, wrestler, golfer, athlete, chef, fashion designer, dancer.

```sparql
VALUES ?job { wd:Q33999 wd:Q10800557 wd:Q10798782 wd:Q177220 wd:Q639669 wd:Q2252262 wd:Q488205
  wd:Q937857 wd:Q3665646 wd:Q10833314 wd:Q11338576 wd:Q4610556 wd:Q245068 wd:Q947873 wd:Q17125263
  wd:Q2526255 wd:Q378622 wd:Q12299841 wd:Q19204627 wd:Q11607585 wd:Q13474373 wd:Q11303721
  wd:Q11513337 wd:Q3499072 wd:Q3501317 wd:Q5716684 }
?item wdt:P106 ?job . ?item wdt:P31 wd:Q5 . ?item wikibase:sitelinks ?sitelinks .
FILTER(?sitelinks >= 20) ?item wdt:P569 ?born . FILTER(YEAR(?born) >= 1900)
```

Very famous politicians, business people, writers, royals and the like (60+ sitelinks): the same, with
`VALUES ?job { wd:Q82955 wd:Q43845 wd:Q36180 wd:Q116 wd:Q2304859 wd:Q901 wd:Q1028181 }` and `>= 60`.

### Brand

Companies (business, public company, enterprise, car maker, airline, retail chain, commercial
organization, online service, private company, tech company, telecoms, video game developer), 10+:

```sparql
VALUES ?type { wd:Q4830453 wd:Q891723 wd:Q6881511 wd:Q786820 wd:Q46970 wd:Q507619 wd:Q21980538
  wd:Q19967801 wd:Q1589009 wd:Q18388277 wd:Q2401749 wd:Q210167 }
?item wdt:P31 ?type . ?item wikibase:sitelinks ?sitelinks . FILTER(?sitelinks >= 10)
```

Product brands (brand, trademark, car brand, food brand, supermarket, restaurant and fast food chains,
beer brand, cosmetics brand, and kinds of soft drink, cola, energy drink, chocolate bar), 5+:

```sparql
{ VALUES ?type { wd:Q431289 wd:Q167270 wd:Q10429667 wd:Q16323605 wd:Q18043413 wd:Q18534542
    wd:Q18509232 wd:Q15075508 wd:Q55315112 } ?item wdt:P31 ?type . }
UNION { VALUES ?kind { wd:Q147538 wd:Q134041 wd:Q215754 wd:Q1361086 } ?item wdt:P279 ?kind . }
?item wikibase:sitelinks ?sitelinks . FILTER(?sitelinks >= 5)
```
