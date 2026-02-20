/*==============================================================*/
/* Spatial Analysis of 5-Year Home Price Appreciation in the Kansas City MSA */
/* Matthew Ong | mong01@tamu.edu | February 2026                */
/*==============================================================*/


/*--------------------------------------------------------------*/
/* 1. Setup                                                     */
/*--------------------------------------------------------------*/
options dlcreatedir;

/* Set working directory manually before running script */
/* Example: set your SAS working directory to the project root */

libname data "./data";

%let price_csv  = ./data/price_data.csv;
%let zips_csv   = ./data/target_zips.csv;
%let export_csv = ./data/kc_price_appreciation.csv;
/*--------------------------------------------------------------*/
/* 2. Import Data                                               */
/*--------------------------------------------------------------*/
proc import datafile="&price_csv"
    out=data.zip_wide
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=max;
run;

proc import datafile="&zips_csv"
    out=data.target_zips
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=max;
run;


/*--------------------------------------------------------------*/
/* 3. Filter to Kansas City MSA ZIP Codes                      */
/*--------------------------------------------------------------*/
proc sql;
    create table data.filtered as
    select *
    from data.zip_wide
    where RegionName in
        (select RegionName from data.target_zips);
quit;


/*--------------------------------------------------------------*/
/* 4. Reshape: Wide → Long Format                              */
/*--------------------------------------------------------------*/
proc sort data=data.filtered;
    by RegionName;
run;

proc transpose data=data.filtered
    out=data.zip_long
    name=date_raw;
    by RegionName;
    var _:;
run;

data data.zip_long;
    set data.zip_long;
    rename col1 = avg_price;
run;


/*--------------------------------------------------------------*/
/* 5. Data Cleaning                                             */
/*--------------------------------------------------------------*/

/* Convert ZIP to character (5-digit format) */
data data.zip_long;
    set data.zip_long;
    length RegionName_char $5;
    RegionName_char = put(RegionName, z5.);
    drop RegionName;
    rename RegionName_char = RegionName;
run;

/* Replace zero prices with missing */
data data.zip_long;
    set data.zip_long;
    if avg_price = 0 then avg_price = .;
run;

/* Convert string dates to SAS date format */
data data.zip_long;
    set data.zip_long;

    clean_date = substr(date_raw, 2);
    clean_date = tranwrd(clean_date, '_', '-');
    date = input(clean_date, mmddyy10.);
    format date date9.;

    drop clean_date date_raw;
run;

proc sort data=data.zip_long;
    by RegionName date;
run;


/*--------------------------------------------------------------*/
/* 6. Compute 5-Year Log Growth                                */
/*--------------------------------------------------------------*/

/* Identify most recent date dynamically */
proc sql noprint;
    select max(date) into :max_date
    from data.zip_long;
quit;

/* Keep most recent 60 months */
data data.last5;
    set data.zip_long;
    where date >= intnx('month', &max_date, -60);
run;

proc sort data=data.last5;
    by RegionName date;
run;

/* Compute cumulative 5-year log growth */
data data.zip_5yr_growth;
    set data.last5;
    by RegionName;
    retain first_price;

    if first.RegionName then first_price = avg_price;

    if last.RegionName then do;

        if first_price > 0 and avg_price > 0 then do;

            /* 5-Year Log Growth:
               G_i = log(P_T) - log(P_0) */

            cum_5yr_log_growth = log(avg_price) - log(first_price);

            /* Baseline Log Price:
               log(P_0) */

            log_initial_price  = log(first_price);

            output;
        end;

    end;

    keep RegionName cum_5yr_log_growth log_initial_price;
run;


/*--------------------------------------------------------------*/
/* 7. Export Final Dataset                                      */
/*--------------------------------------------------------------*/
proc export data=data.zip_5yr_growth
    outfile="&export_csv"
    dbms=csv
    replace;
run;


