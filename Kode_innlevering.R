Sys.setlocale(locale="no_NO")

# Help file for assignment 1 - sok-2011 2022 
library(dplyr)
library(plyr)
library(ggplot2)
library(WDI)
library(tidyverse)
library(countrycode)
library(psych)
library(Hmisc)

# WDIsearch(string = "search item", field = "name", short = TRUE, cache = NULL)

#   NY.GDP.PCAP.PP.KD (gdppc) = BNP per innbygger (PPP) 
#   NY.ADJ.NNAT.GN.ZS (nsy) = Sparing som andel av BNI (netto)
#   SP.POP.TOTL (poptot) = Befolkningsstørrelse
#   JI.TLF.TOTL (lf) = Størrelse på arbeidskraften
#   SP.POP.GROW (p) = Vekstrate i befolkningen
#   BAR.SCHL.15UP (educ) = Gjennomsnittlig antall år i skole (befolkning 15+)
#   SPI.D3.4.EDUC = kvalitet på skole. Mulig alternativ til gjennomsnittlig antall år i skole
#   NE.GDI.FTOT.KD.ZG (gi) = Årlig vekstrate i investeringer
#   NE.EXP.GNFS.KD.ZG (gx) = Årlig vekstrate i eksport
#   NY.ADJ.DRES.GN.ZS (nry) = Årlig reduksjonsrate i naturressurser

WDIsearch(string = "growth", field = "name", short = TRUE, cache = NULL)


# 1. BNP per innbyggere (alle år) og initial nivå på BNP per innbyggere. WDI-variabel =  "NY.GDP.PCAP.PP.KD". 
# Velg startår = 2000 og sluttår = 2019

df_gdp0<-WDI(
  country = "all",
  indicator = c('gdppc'="NY.GDP.PCAP.PP.KD"),  
  start = 2000,
  end = 2019,
  extra = TRUE, # det å sette "extra = TRUE" fører til at vi laster inn ekstra informasjon som vi kan benytte seinere (f.eks. variabelen "region")
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_gdp <- subset(df_gdp0, select = c(country, region, income, iso2c, iso3c, year, gdppc) ) %>%  arrange(iso3c, year) # velg ut relevante variabler
df_gdp <-  df_gdp %>% mutate_all(na_if,"") # Vi ønsker å ta vekk land som ikke har en iso3c kode. Dessverre er manglende observasjoner for "iso3c" (landkode) kodet som "blanks" isteden for "missing". Denne koden korrigerer dette.
df_gdp <- df_gdp[complete.cases( df_gdp$gdppc, df_gdp$iso3c),] # Ta vekk observasjoner som mangler data på gdppc og iso3c. 
df_gdp = df_gdp  %>%  
  mutate(year = as.numeric(year)) # Se til at year er en numerisk variabel. 

# Noen land har flere observasjoner for samme år (f.eks afghanistan år 2010). Vi ønsker å ha én observasjon per land og år. 
df_gdp <- df_gdp[!duplicated(df_gdp[c("iso3c", "year", max("gdppc"))]), ]  %>%  arrange(iso3c, year) # Ta vekk duplikater for land og år, behold observasjonen med størst gdppc (denne regelen kan diskuteres)

# Lag et datasett med Y0 (nivå på BNP per innbyggere i år 2000)
df_gdp2000  <- df_gdp %>%  arrange(iso3c, year) %>% group_by(iso3c) %>% #Behold den første observasjonen for BNP per innbyggere (Y0)
  slice(1) %>%
  ungroup()
df_gdp2000 = subset(df_gdp2000, select = -c(year) ) # Slett unødvendige variabler
df_gdp2000 <-   plyr:: rename(df_gdp2000,c("gdppc" = "gdppc0")) # Gi variabeln et nytt navn slik at vi kan identifisere den i datasetet. 

df_gdp <- left_join(df_gdp,df_gdp2000, by=c("country", "iso2c", "iso3c", "region", "income")) # Sett sammen data for BNP per innbygger alle år, med BNP per innbygger år 2000.

#View(df_gdp)

# 2. Humankapital (gjennomsnittlig antall år i skole blant befolkningen eldre enn 15 år). WDI-variabel = BAR.SCHL.15UP 
df_educ0<-WDI(
  country = "all",
  indicator = c('educ'="BAR.SCHL.15UP"),  
  start = 2000,
  end = 2019,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_educ <- subset(df_educ0, select = c(country, region, income, iso2c, iso3c, year, educ) ) %>%  arrange(iso3c, year) #Behold nødvendige variabler
df_educ <- df_educ[complete.cases(df_educ$educ),] %>%  arrange(iso3c, year) # Slett observasjoner med manglende data

df_educ = df_educ %>%  
  arrange(iso3c, year) %>%  # Sorter etter Iso-kode og år. 
  mutate(educ = as.numeric(educ, na.rm = TRUE)) %>% # Se til at variabelen er numerisk
  ddply("iso3c",transform,
        avg_educ=mean(educ, na.rm = TRUE))  # Beregne gjennomsnittlig år i skole for tidsperioden 2000 - 2019 for hvert land, basert på tilgjenglig data (vil være 2000.2005,2010)

df_educ <- subset(df_educ, select = c(country, region, income, iso2c, iso3c, avg_educ)) # Her tar jeg vekk variabelen "year". Jeg gjør dette fordi vi bare har en observasjon på utdanning per land. Vi ønsker å bruke denne verdi for alle år. 
df_educ <- df_educ[!duplicated(df_educ[c("iso3c")]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for hvert land.
#View (df_educ)

# 3. Gjennomsnittlig sparing for perioden 2000-2015 (lagg fordi det kan ta litt tid for sparing å bli til investering)
df_nsy0<-WDI(
  country = "all",
  indicator = c( 'nsy'="NY.ADJ.NNAT.GN.ZS"),  
  start = 2000,
  end = 2015,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_nsy <- subset(df_nsy0, select = c(country, region, income, iso2c, iso3c, year, nsy) ) %>%  arrange(iso3c, year) #Behold nødvendige variabler
df_nsy <- df_nsy[complete.cases(df_nsy$nsy),] %>%  arrange(iso3c, year) # Slett observasjoner med manglende data


df_nsy = df_nsy %>%  
  arrange(iso3c, year) %>%  # Sorter etter Iso-kode og år. 
  mutate(nsy = as.numeric(nsy, na.rm = TRUE)) %>% # Se til at variabelen er numerisk
  ddply("iso3c",transform,
        avg_nsy=mean(nsy, na.rm = TRUE))  # Beregne gjennomsnittlig år i skole for tidsperioden 2000 - 2019 for hvert land, basert på tilgjenglig data (vil være 2000.2005,2010)

df_nsy <- subset(df_nsy, select = c(country, region, income, iso2c, iso3c, avg_nsy)) # Her tar jeg vekk variabelen "year". Jeg gjør dette fordi vi bare har en observasjon på utdanning per land. Vi ønsker å bruke denne verdi for alle år. 
df_nsy <- df_nsy[!duplicated(df_nsy[c("iso3c")]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for hvert land.

#View(df_nsy)

# 4. Vekst i arbeidskraften (n)
df_lf0<-WDI(
  country = "all",
  indicator = c('lf'="JI.TLF.TOTL"),  # lf = labor force
  start = 2000,
  end = 2019,
  extra = TRUE, 
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_lf <- subset(df_lf0, select = c(country, region, income, iso2c, year, lf) ) %>%  arrange(iso2c, year) # velg ut relevante variabler
df_lf <-   plyr:: rename(df_lf,c("iso2c" = "iso3c")) # variabelen som identifiserer land med kode er feil i datasetet. Dette korrigerer dette
df_lf <-  df_lf %>% mutate_all(na_if,"") 
df_lf [df_lf == 0]<-NA
df_lf <- df_lf[complete.cases(df_lf$iso3c, df_lf$lf),] # Ta vekk observasjoner som mangler data på lf og iso3c. 
df_lf = df_lf  %>%  
  mutate(year = as.numeric(year)) # Se til at year er en numerisk variabel. 

df_lf <- df_lf[!duplicated(df_lf[c("iso3c", "year")]), ]  %>%  arrange(iso3c, year) # Ta vekk duplikater for land og år

# Ta fram vekstraten i arbeidskraften (n). Vi har ikke data for hvert år i alle land. 
# For å beregne gjennomsnittlig årlig vekst må vi lage en variabel som måler antallet tidsperioder mellom hver observasjon.
df_n = df_lf %>%  
  arrange(iso3c, year) %>%  # Sorter på år og land
  ddply("iso3c",transform,
        t=c(NA,diff(year)),
        lf_growth=c(NA,diff(log(lf)))) #Vekstrate uten hensyn til tidsintervall

df_n <- df_n[complete.cases(df_n$t, df_n$lf_growth),] # Ta vekk observasjoner som mangler data på t

#Nå kan vi ta fram årlig vekstrate
df_n = df_n %>%  
        mutate(t = as.numeric(t)) %>%   
        mutate(lf_growth = as.numeric(lf_growth))
df_n <- transform(df_n, n =lf_growth/t)

# gjennomsnittlig vekstrate i arbeidskraften for hvert land
df_n <- df_n %>% # 
          ddply("iso3c",transform,
                avg_n=mean(n, na.rm = TRUE)) #Gjennomsnittlig årlig vekstrate i arbeidskraften

df_n <- subset(df_n, select = c(iso3c, avg_n) )
df_n <- df_n[!duplicated(df_n["iso3c"]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for land

#View(df_n)


# 5. Lag et datasett som inneholder BNP data, utdanningsdata, sparing, og lfp data

df <- left_join(df_gdp, df_educ, by=c("country", "iso2c", "iso3c", "region", "income"))
df <- left_join(df, df_nsy, by=c("country", "iso2c", "iso3c", "region", "income"))
df <- left_join(df, df_n, by="iso3c")
df <- subset(df, select = c(country, region, income, iso2c, iso3c, year, gdppc, gdppc0, avg_educ, avg_nsy, avg_n)) # Behold nødvendige variabler

# Mange observasjoner representerer aggregerte regioner. Vi ønsker å ta vekk disse. Det finnes helt sikkert en bedre måte å gjøre dette på. Dette er den måten jeg kom på.
df <- df  %>%  filter(iso2c!='1A' & iso2c !='1W' & iso2c != '4E' & iso2c != '7E' & iso2c !='8S'
                                         & iso2c !='B8' & iso2c !='EU' & iso2c !='F1' & iso2c !='OE' & iso2c !='S1' & iso2c !='S2' & iso2c !="S3" 
                                         & iso2c !='S4' & iso2c !='T2' & iso2c !='T3' & iso2c !='T4' & iso2c !='T5' & iso2c !='T6' & iso2c !='T7' 
                                         & iso2c !='V1' & iso2c !='V2' & iso2c !='V3' & iso2c !='V4' & iso2c !='XC' & iso2c !='XD' & iso2c !='XE' 
                                         & iso2c !='XF' & iso2c !='XG' & iso2c !='XH' & iso2c !='XI' & iso2c !='XJ' & iso2c !='XL' & iso2c !='XM' 
                                         & iso2c !='XN' & iso2c !='XO' & iso2c !='XP' & iso2c !='XQ' & iso2c !='XT' & iso2c !='XU' & iso2c !='Z4' 
                                         & iso2c !='Z7' & iso2c !='ZF'& iso2c !='ZG'  & iso2c !='ZH' & iso2c !='ZI'  & iso2c !='ZJ'  & iso2c !='ZQ'  
                                         & iso2c !='ZT'  & iso2c !='Z7')  %>% arrange(iso3c, year) 
#View(df)

# 6. Lag et datasett for resterende variabler.

df_rest0<-WDI(
  country = "all",
  indicator = c('poptot'="SP.POP.TOTL", 'gi'="NE.GDI.FTOT.KD.ZG", 'gx'="NE.EXP.GNFS.KD.ZG", 'nry'="NY.ADJ.DRES.GN.ZS", 'p'="SP.POP.GROW" ),  
  start = 2000,
  end = 2019,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_rest0<-df_rest0 %>% mutate_all(na_if,"")
df_rest <- df_rest0[complete.cases( df_rest0$iso3c),]  %>%  arrange(iso2c) 


# Ta vekk observasjoner som ikke representerer land.
df_rest <- df_rest  %>%  filter(iso2c!='1A' & iso2c !='1W' & iso2c != '4E' & iso2c != '7E' & iso2c !='8S'
                                  & iso2c !='B8' & iso2c !='EU' & iso2c !='F1' & iso2c !='OE' & iso2c !='S1' & iso2c !='S2' & iso2c !="S3" 
                                  & iso2c !='S4' & iso2c !='T2' & iso2c !='T3' & iso2c !='T4' & iso2c !='T5' & iso2c !='T6' & iso2c !='T7' 
                                  & iso2c !='V1' & iso2c !='V2' & iso2c !='V3' & iso2c !='V4' & iso2c !='XC' & iso2c !='XD' & iso2c !='XE' 
                                  & iso2c !='XF' & iso2c !='XG' & iso2c !='XH' & iso2c !='XI' & iso2c !='XJ' & iso2c !='XL' & iso2c !='XM' 
                                  & iso2c !='XN' & iso2c !='XO' & iso2c !='XP' & iso2c !='XQ' & iso2c !='XT' & iso2c !='XU' & iso2c !='Z4' 
                                  & iso2c !='Z7' & iso2c !='ZF'& iso2c !='ZG'  & iso2c !='ZH' & iso2c !='ZI'  & iso2c !='ZJ'  & iso2c !='ZQ'  
                                  & iso2c !='ZT'  & iso2c !='Z7')  %>% arrange(iso3c, year) 

df_rest <- subset(df_rest, select = c("country", "region", "income", "iso3c", "iso2c", "year", "poptot", "p", "nry", "gi", "gx"))
df_all <- left_join(df, df_rest, by=c("country", "region", "income", "iso2c", "iso3c", "year"))

# View(df_all)

# Lag en rekkefølge til variablene slik at det er enklere å få en oversikt over datamaterialet.
col_order <- c("country",  "region", "income", "iso3c", "iso2c", "year", "gdppc", "gdppc0", "poptot", "p", "avg_n", "avg_nsy", "nry", "gi", "gx", "avg_educ")
df_all <- df_all[, col_order]

#View(df_all)

# Ta fram vekstraten og gjennomsnitt for resterende variabler
df_growth0 = df_all %>%  
  arrange(iso3c, year) %>%  # Sorter på år og land
  ddply("iso3c",transform,
        gdpgrowth=c(NA,diff(log(gdppc)))*100) %>%   # Årlig vekstrate i gdppc for hvert land
  mutate(gdpgrowth = as.numeric(gdpgrowth, na.rm = TRUE)) %>% # 
  ddply("iso3c",transform,
        avg_gdpgrowth=mean(gdpgrowth, na.rm = TRUE), #Gjennomsnittlig årlig vekstrate i BNP per innbygger for hvert land i perioden
        avg_gi=mean(gi, na.rm = TRUE), # Gjennomsnittlig årlig vekstrate i investeringer for hvert land  i perioden
        avg_nry=mean(nry, na.rm = TRUE),  # Gjennomsnittlig årlig vekstrate (negativ) i naturressurser for hvert land  i perioden
        avg_gx=mean(gx, na.rm = TRUE),  # Gjennomsnittlig årlig vekstrate i eksport for hvert land  i perioden
        avg_p=mean(p, na.rm = TRUE))  # Gjennomsnittlig årlig vekstrate i befolkningen for hvert land  i perioden
        
#View(df_growth0)
df_growth0 <-  df_growth0 %>% mutate_all(na_if,"") 
df_growth <- df_growth0[complete.cases( df_growth0$country, df_growth0$income, df_growth0$iso3c, df_growth0$avg_gdpgrowth, df_growth0$gdppc0, df_growth0$avg_n, df_growth0$avg_p, df_growth0$avg_nsy, df_growth0$avg_nry,df_growth0$avg_gi, df_growth0$avg_gx, df_growth0$avg_educ),] # Ta vekk land som mangler data 


df_growth <- subset(df_growth, select = c("country",  "region", "income", "iso3c", "iso2c","year", "poptot", "gdppc", "gdppc0", "avg_gdpgrowth", "avg_n", "avg_p", "avg_nsy", "avg_nry", "avg_gi", "avg_gx", "avg_educ"))

# Lag datasettet du vil bruke til analysen din
df_growth2019  <- df_growth %>%  arrange(iso3c, year) %>% group_by(iso3c) %>% 
  slice(n()) %>% # Behold den SISTE observasjonen for hvert land
  ungroup()
head(df_growth2019)

# Lag en variabel som er logaritmen av BNP per innbygger (enklere tolkning og presser sammen fordelingen)
df_growth2019$dppc <-as.numeric(df_growth2019$gdppc)
df_growth2019$ln_gdppc<-log(df_growth2019$gdppc) 
df_growth2019$ln_gdppc0<-log(df_growth2019$gdppc0) 

# View(df_growth2019)

# Grafer til introduksjon
library(gapminder)

citation("gapminder")

head(gapminder)

#view(gapminder)

gapminder2007 <- gapminder %>% 
  filter(year == 2007)

head(gapminder2007)

plot1 <- ggplot(gapminder2007, aes(x=gdpPercap, y=lifeExp)) +
  geom_point(aes(size = pop, color = continent)) +
  labs(title = "Økonomisk vekst og forventet levealder",
       subtitle = "(Data for 2007)",
       y = "Forventet levealder",
       x = "BNP per innbygger",
       color = "Kontinent") +
  scale_size_area(guide = "none", max_size = 7)

plot2 <- ggplot(gapminder2007, aes(x=gdpPercap, y=lifeExp)) +
  geom_point(aes(size = pop, color = continent)) +
  labs(title = "Økonomisk vekst og forventet levealder (zoomet inn)",
       subtitle = "(Data for 2007)",
       y = "Forventet levealder",
       x = "BNP per Innbygger",
       color = "Kontinent") +
  scale_size_area(guide = "none", max_size = 7) +
  coord_cartesian(xlim=c(0,10000))

library(gridExtra)
grid.arrange(plot1, plot2, ncol=2)


# Deskriptiv analyse
library(vtable)
library(car)
library(knitr)

# 1. En tabell med deskriptiv statistiskk (gjennomsnitt, standard avvik, min og maks)
# Velg ut de variabler du vil ha med i tabellen
#NB: Du må selv legge til variabler her!
df <- subset(df_growth2019, select = c("avg_gdpgrowth", "avg_nsy", "avg_p", "avg_educ",
                                         "avg_gi", "avg_gx", "avg_nry", "gdppc0"))
#Gi variablene navn som gir mening. NB: rekkefølgen må være lik rekkefølgen til variablene i df.
labs <- c("Vekst i BNP pc (%)", "Vekst i sparing (%)",
          "Vekst i befolkning (%)", "Gjennomsnittlig lengde skolegang (ÅR)", 
          "Vekst i investeringer (%)", "Vekst i eksport (%)", "Reduksjon i naturressurser (%)",
          "BNP per innbygger i år 2000")


#Lag tabellen
st(df, labels=labs)
st(df, vars =c("avg_gdpgrowth", "avg_nsy", "avg_p", "avg_educ",
               "avg_gi", "avg_gx", "avg_nry", "gdppc0"))
st(df, labels=labs,
   summ = list(
     c('notNA(x)','mean(x)','sd(x)','min(x)','max(x)'), # Dette beskriver hvilken informasjon du vil ha med i tabellen
     c('notNA(x)','mean(x)')
   ),
   summ.names = list(
     c('Antall observasjoner','Gjennomsnitt','Standardavvik',
       'Minimum','Maksimum') #Dette setter titler til kolumnene.
  ))


# 2. Grafer

# Vekst i BNP pc og vekst i sparing
df_growth2019 %>% 
  ggplot(aes(x = avg_nsy, y = ln_gdppc)) +
  geom_point(aes(size = poptot, color = region), alpha = 0.7) +
  labs(title = "4. BNP per capita og sparing",
       x = "Årlig vekstrate sparing",
       y = "BNP per capita (2019)") +
  scale_size_area(guide = "none", max_size = 14) + 
  theme(legend.text = element_text(size = 10,color="black")) +
  scale_colour_manual(values = rainbow(7)) +
  scale_x_continuous(breaks=seq(-10,30,5)) +
  theme_minimal()


# Vekst i BNP pc og befolkningsvekst
df_growth2019 %>% 
  ggplot(aes(x = avg_p, y = ln_gdppc)) +
  geom_point(aes(size = poptot, color = region), alpha = 0.7) +
  labs(title = "5. BNP per capita og befolkningsvekst",
       x = "Årlig befolkningsvekst",
       y = "BNP per capita (2019)") +
  scale_size_area(guide = "none", max_size = 14) + 
  theme(legend.text = element_text(size = 10,color="black")) +
  scale_colour_manual(values = rainbow(7)) +
  scale_x_continuous(breaks=c(-1, -0.5, 0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 )) +
  theme_minimal()

# Vekst i BNP pc og humankapital
df_growth2019 %>% 
  ggplot(aes(x = avg_educ, y = ln_gdppc)) +
  geom_point(aes(size = poptot, color = region), alpha = 0.7) +
  labs(title = "6. BNP per capita og humankapital",
       x = "Gjennomsnittlig lengde utdanning",
       y = "BNP per capita (2019)") +
  scale_size_area(guide = "none", max_size = 14) + 
  theme(legend.text = element_text(size = 10,color="black")) +
  scale_colour_manual(values = rainbow(7)) +
  scale_x_continuous(breaks=c(1, 2, 3, 4, 5, 6,
                              7, 8, 9, 10, 11, 12, 13)) +
  theme_minimal()

# Årlig vekstrate i BNP pc og sparing
df_growth2019 %>% 
  ggplot(aes(x = avg_nsy, y = avg_gdpgrowth)) +
  geom_point(aes(size = poptot, color = region), alpha = 0.7) +
  labs(title = "7. Årlig vekstrate i BNP per capita og sparing",
       x = "Årlig vekstrate i sparing",
       y = "Årlig vekstrate i BNP per capita") +
  scale_size_area(guide = "none", max_size = 14) + 
  theme(legend.text = element_text(size = 10,color="black")) +
  scale_colour_manual(values = rainbow(7)) +
  scale_x_continuous(breaks=seq(-10,30,5)) +
  theme_minimal()

# Årlig vekstrate i BNP pc og humankapital
df_growth2019 %>% 
  ggplot(aes(x = avg_educ, y = avg_gdpgrowth)) +
  geom_point(aes(size = poptot, color = region), alpha = 0.7) +
  labs(title = "8. Årlig vekstrate i BNP per capita og humankapital",
       x = "Gjennomsnittlig lengde utdanning",
       y = "Årlig vekstrate i BNP per capita") +
  scale_size_area(guide = "none", max_size = 14) + 
  theme(legend.text = element_text(size = 10,color="black")) +
  scale_colour_manual(values = rainbow(7)) +
  scale_x_continuous(breaks=c(1, 2, 3, 4, 5, 6,
                              7, 8, 9, 10, 11, 12, 13)) +
  theme_minimal()

# Sjekk om det er ekstreme observasjoner i data
model1 <- lm(avg_gdpgrowth  ~ avg_gi , data=  df_growth2019 ) #NB: Du må legge inn "Dine" variabler her
summary(model1)
# Vi har ekstreme observasjoner i datamaterialet. Vi må sjekke hvordan resultatene påvirkes av at vi tar vekk disse. 
# Koden her nede følger metoden som er beskrevet her: https://www.r-bloggers.com/2021/09/how-to-remove-outliers-in-r-3/ for reference

# Basert på den grafiske analysen av sammenhengen mellom vekst i BNP per innbygger og vekst i investeringer, starter jeg med å se på ekstreme observasjoner i avg_gi
Q1gi <- quantile(df_growth2019$avg_gi, .25 )
Q3gi <- quantile(df_growth2019$avg_gi, .75)
IQRgi <- IQR(df_growth2019$avg_gi)
no_outliers1 <- subset(df_growth2019, df_growth2019$avg_gi > (Q1gi - 1.5*IQRgi) & df_growth2019$avg_gi < (Q3gi + 1.5*IQRgi))
dim(no_outliers1)

#View (no_outliers1)
model2 <- lm(avg_gdpgrowth  ~ avg_nsy + avg_p + avg_educ +
               avg_gi + avg_gx + avg_nry + gdppc0, data= no_outliers1) #NB: Du må legge inn "Dine" variabler her
summary(model2)

library(sjPlot)

Sys.setlocale(locale="no_NO")


labs2 <- c("Vekst i BNP pc (%)", "Gjennomsnittlig sparing som andel av BNI",
          "Gjennomsnittlig vekstrate i befolkning", "Gjennomsnittlig antall år i skole (for befolkning 15+)", "Gjennomsnittlig årlig vekstrate i investeringer",
          "Gjennomsnittlig årlig vekstrate i eksport", "Gjennomsnittlig årlig reduksjonsrate i naturressurser",
          "BNP per innbygger i år 2000")

tab_model(model2, pred.labels = labs2, encoding = "UTF-8", CSS = list(
  css.depvarhead = 'color: red;',
  css.centeralign = 'text-align: left;', 
  css.firsttablecol = 'font-weight: bold;', 
  css.summary = 'color: blue;', 'font-weight:bold;',
  css.table = 'border:2px solid red;'))

tab_model(model2, file = "resultat.html", pred.labels = labs2, encoding = "UTF-8", CSS = list(
  css.depvarhead = 'color: red;',
  css.centeralign = 'text-align: left;', 
  css.firsttablecol = 'font-weight: bold;', 
  css.summary = 'color: blue;', 'font-weight:bold;',
  css.table = 'border:2px solid red;'))

 # Jeg kan deretter gå videre å se om det er andre ekstreme observasjoner i andre variabler. 


