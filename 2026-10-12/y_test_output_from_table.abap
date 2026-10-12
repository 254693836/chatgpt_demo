REPORT y_test_output_from_table.

" Output directory. Change the default only to an application-server directory
" for which the executing user has S_DATASET authorization.
PARAMETERS p_dir TYPE string LOWER CASE DEFAULT '/usr/sap/interfaces/reports'.

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

FORM output_table_to_csv USING it_table    TYPE ANY TABLE
                               iv_file_name TYPE string.
  DATA: lv_path     TYPE string,
        lv_line     TYPE string,
        lv_cell     TYPE string,
        lo_type     TYPE REF TO cl_abap_typedescr,
        lo_structure TYPE REF TO cl_abap_structdescr.
  FIELD-SYMBOLS: <ls_row>   TYPE any,
                 <lv_value> TYPE any.

  " p_dir is the report parameter that fixes the output destination.
  lv_path = |{ p_dir }/{ iv_file_name }|.
  OPEN DATASET lv_path FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
  IF sy-subrc <> 0.
    MESSAGE |Cannot open output file: { lv_path }| TYPE 'E'.
  ENDIF.

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

    TRANSFER lv_line TO lv_path.
  ENDLOOP.

  CLOSE DATASET lv_path.
  MESSAGE |CSV created: { lv_path }| TYPE 'S'.
ENDFORM.

FORM escape_csv CHANGING cv_value TYPE string.
  REPLACE ALL OCCURRENCES OF '"' IN cv_value WITH '""'.
  cv_value = |"{ cv_value }"|.
ENDFORM.
