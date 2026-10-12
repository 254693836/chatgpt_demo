REPORT y_test_output_from_table.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_server RADIOBUTTON GROUP dst DEFAULT 'X' USER-COMMAND dst,
            p_local  RADIOBUTTON GROUP dst.
" Application-server directory. The user needs S_DATASET authorization.
PARAMETERS: p_srvdir TYPE string LOWER CASE
                       DEFAULT '/usr/sap/interfaces/reports' MODIF ID srv,
" Frontend (PC) directory. Example: C:\temp
            p_lcldir TYPE string LOWER CASE DEFAULT 'C:\temp' MODIF ID loc.
SELECTION-SCREEN END OF BLOCK b01.

TYPES: BEGIN OF ty_demo_row,
         employee_id TYPE i,
         name        TYPE string,
         department  TYPE string,
         amount      TYPE p LENGTH 8 DECIMALS 2,
       END OF ty_demo_row,
       ty_demo_table TYPE STANDARD TABLE OF ty_demo_row WITH EMPTY KEY.

DATA gt_demo TYPE ty_demo_table.

START-OF-SELECTION.
  " Example only: replace gt_demo with any internal table in the calling report.
  gt_demo = VALUE #( ( employee_id = 1001 name = 'Tanaka, Aki' department = 'Sales' amount = '1250.50' )
                     ( employee_id = 1002 name = 'Sato "Ken"' department = 'Support' amount = '980.00' ) ).

  " The FORM accepts every internal-table type; only the output name is fixed.
  PERFORM output_table_to_csv USING gt_demo 'demo_report.csv'.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'SRV'.
        screen-active = COND #( WHEN p_server = 'X' THEN 1 ELSE 0 ).
      WHEN 'LOC'.
        screen-active = COND #( WHEN p_local = 'X' THEN 1 ELSE 0 ).
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

FORM output_table_to_csv USING it_table    TYPE ANY TABLE
                               iv_file_name TYPE string.
  DATA: lv_path     TYPE string,
        lv_line     TYPE string,
        lv_cell     TYPE string,
        lo_type     TYPE REF TO cl_abap_typedescr,
        lo_structure TYPE REF TO cl_abap_structdescr.
  DATA lt_csv_lines TYPE STANDARD TABLE OF string WITH EMPTY KEY.
  FIELD-SYMBOLS: <ls_row>   TYPE any,
                 <lv_value> TYPE any.

  LOOP AT it_table ASSIGNING <ls_row>.
    CLEAR lv_line.
    lo_type = cl_abap_typedescr=>describe_by_data( <ls_row> ).

    IF lo_type->kind = cl_abap_typedescr=>kind_struct.
      lo_structure ?= lo_type.
      LOOP AT lo_structure->components INTO DATA(ls_component).
        ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_row> TO <lv_value>.
        IF sy-subrc = 0.
          lv_cell = |{ <lv_value> }|.
          PERFORM escape_csv CHANGING lv_cell.
          IF lv_line IS INITIAL.
            lv_line = lv_cell.
          ELSE.
            lv_line = |{ lv_line },{ lv_cell }|.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ELSE.
      lv_cell = |{ <ls_row> }|.
      PERFORM escape_csv CHANGING lv_cell.
      lv_line = lv_cell.
    ENDIF.

    APPEND lv_line TO lt_csv_lines.
  ENDLOOP.

  IF p_server = 'X'.
    lv_path = |{ p_srvdir }/{ iv_file_name }|.
    OPEN DATASET lv_path FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
    IF sy-subrc <> 0.
      MESSAGE |Cannot open application-server file: { lv_path }| TYPE 'E'.
    ENDIF.

    LOOP AT lt_csv_lines INTO lv_line.
      TRANSFER lv_line TO lv_path.
    ENDLOOP.
    CLOSE DATASET lv_path.
  ELSE.
    " GUI_DOWNLOAD writes to the SAP GUI frontend, not to the ABAP server.
    lv_path = |{ p_lcldir }/{ iv_file_name }|.
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename = lv_path
        filetype = 'ASC'
        codepage = '4110'
      TABLES
        data_tab = lt_csv_lines
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      MESSAGE |Cannot create local file: { lv_path }| TYPE 'E'.
    ENDIF.
  ENDIF.

  MESSAGE |CSV created: { lv_path }| TYPE 'S'.
ENDFORM.

FORM escape_csv CHANGING cv_value TYPE string.
  REPLACE ALL OCCURRENCES OF '"' IN cv_value WITH '""'.
  cv_value = |"{ cv_value }"|.
ENDFORM.
