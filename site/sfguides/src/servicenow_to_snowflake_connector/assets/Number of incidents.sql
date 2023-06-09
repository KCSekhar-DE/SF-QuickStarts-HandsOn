
USE DATABASE SERVICENOW_DEST_DB;
USE SCHEMA DEST_SCHEMA;
USE WAREHOUSE SERVICENOW_WAREHOUSE;

BEGIN CALL
 "SNOWFLAKE_CONNECTOR_FOR_SERVICENOW"."PUBLIC".CONFIGURE_CONNECTOR_TABLES('schedule_interval','30m','cmdb,cmdb_ci, incident, sc_req_item, sc_request,sys_audit,sys_audit_delete, sys_choice, sys_user, sys_user_group, task'); 
 
 CALL "SNOWFLAKE_CONNECTOR_FOR_SERVICENOW"."PUBLIC".ENABLE_TABLES('cmdb, cmdb_ci, incident, sc_req_item, sc_request,sys_audit,sys_audit_delete, sys_choice, sys_user, sys_user_group, task', 'true'); 
 END;



WITH T1 AS (
    SELECT
    DISTINCT
        T.NUMBER AS TICKET_NUMBER
        ,G1.NAME AS PARENT_ASSIGNMENT_GROUP
        ,G.NAME AS CHILD_ASSIGNMENT_GROUP
        ,T.SHORT_DESCRIPTION
        ,T.DESCRIPTION
        ,CI.NAME AS CONFIGURATION_ITEM
      --  ,SC_CAT.LABEL AS CATEGORY
      --  ,SC_SUBCAT.LABEL AS SUBCATEGORY
        ,T.PRIORITY
        ,T.SYS_CREATED_ON AS CREATED_ON
        ,SU.NAME AS ASSIGNED_TO
        ,SU1.NAME AS OPENED_BY
        ,U2.NAME AS INCIDENT_REQUESTED_FOR
        ,T.SYS_UPDATED_ON AS UPDATED_ON
        ,T.CLOSED_AT

    FROM
      TASK__VIEW T
      LEFT JOIN 
          INCIDENT__VIEW I 
          ON I.SYS_ID = T.SYS_ID -- ADDITIONAL INCIDENT DETAIL
  --    LEFT JOIN 
  --        (
 --           SELECT 
  --            * 
  --          FROM 
  --              SYS_CHOICE__VIEW SC_CAT 
  --          WHERE 
  --              ELEMENT = 'U_T_CATEGORY'
  --         ) SC_CAT
  --         ON T.U_T_CATEGORY = SC_CAT.VALUE -- MAPPING FOR CATEGORY VALUES FROM TASK TABLE
      LEFT JOIN 
          (
              SELECT 
              * 
              FROM 
                  SYS_CHOICE__VIEW 
              WHERE 
                  ELEMENT = 'U_T_SUBCATEGORY' 
                  AND NAME ='SC_REQ_ITEM'
          )SC_SUBCAT 
          ON T.U_T_SUBCATEGORY = SC_SUBCAT.VALUE -- MAPPING FOR SUBCATEGORY VALUES FROM TASK TABLE
      LEFT JOIN 
          CMDB_CI__VIEW CI 
          ON T.CMDB_CI_VALUE = CI.SYS_ID -- CONFIGURATION ITEM OR APPLICATION NAME
      LEFT JOIN 
          SC_REQ_ITEM R 
          ON T.SYS_ID = R.SYS_ID -- RITM OR SERVICE REQUEST INFORMATION
      LEFT JOIN 
          SC_REQUEST SR 
          ON R.REQUEST_VALUE = SR.SYS_ID -- RITM REQUESTED FOR INFORMATION
      LEFT JOIN 
          SYS_USER__VIEW SU 
          ON T.ASSIGNED_TO_VALUE = SU.SYS_ID -- ASSIGNED TO USERS NAME
      LEFT JOIN 
          SYS_USER__VIEW SU1 
          ON T.OPENED_BY_VALUE = SU1.SYS_ID -- OPENED BY USERS NAME
      LEFT JOIN 
          SYS_USER__VIEW U2 
          ON I.CALLER_ID_VALUE = U2.SYS_ID -- INCIDENT REQUESTED FOR NAME
      LEFT JOIN 
          SYS_USER_GROUP__VIEW G 
          ON NVL(T.ASSIGNMENT_GROUP_VALUE, T.ASSIGNMENT_GROUP) = G.SYS_ID -- CHILD GROUP NAME
      LEFT JOIN 
          SYS_USER_GROUP__VIEW G1 
          ON NVL(G.PARENT_VALUE, G.PARENT) = G1.SYS_ID -- PARENT GROUPS
      LEFT JOIN 
          SYS_AUDIT_DELETE DEL 
          ON T.SYS_ID = DEL.DOCUMENTKEY -- THIS JOIN HELPS IDENTIFY DELETED TICKETS

    WHERE
        DEL.DOCUMENTKEY IS NULL --  THIS CONDITION HELPS KEEP ALL DELETED RECORDS OUT
    AND
        I.SYS_ID IS NOT NULL -- THIS CONDITION HELPS KEEP JUST THE INCIDENT TICKETS
)
SELECT
    YEAR(CREATED_ON) AS YEAR_CREATED
    ,MONTH(CREATED_ON) AS MONTH_CREATED
    ,CONFIGURATION_ITEM AS APPLICATION
    ,PRIORITY
    ,COUNT(DISTINCT TICKET_NUMBER)
FROM
    T1
GROUP BY
    YEAR_CREATED
    ,MONTH_CREATED
    ,APPLICATION
    ,PRIORITY
ORDER BY
    YEAR_CREATED
    ,MONTH_CREATED
    ,APPLICATION
    ,PRIORITY
;


SELECT table_name, schedule_interval, enabled, last_ingestion_state FROM "SNOWFLAKE_CONNECTOR_FOR_SERVICENOW"."PUBLIC".enabled_tables WHERE TABLE_NAME NOT IN ('sys_db_object','sys_dictionary','sys_glide_object') and  enabled = true ORDER BY TABLE_NAME;