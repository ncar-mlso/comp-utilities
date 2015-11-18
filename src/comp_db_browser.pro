; docformat = 'rst'

;+
; Browse through the MLSO database.
;-


;= helper routines

;+
; Thin procedural wrapper to call `::handle_events` event handler.
;
; :Params:
;   event : in, required, type=structure
;     event structure for event handler to handle
;-
pro comp_db_browser_handleevents, event
  compile_opt strictarr

  widget_control, event.top, get_uvalue=browser
  browser->handle_events, event
end


;+
; Thin procedural wrapper to call `::cleanup_widgets` cleanup routine.
;
; :Params:
;   tlb : in, required, type=long
;     top-level base widget identifier
;-
pro comp_db_browser_cleanup, tlb
  compile_opt strictarr

  widget_control, tlb, get_uvalue=browser
  browser->cleanup_widgets
end


;= API

;+
; Set the window title based on the current filename. Set the filename
; to the empty string if there is no title to display.
;
; :Params:
;   filename : in, required, type=string                                                    
;       filename to display in title
;-
pro comp_db_browser::set_title, filename
  compile_opt strictarr

  title = string(self.title, $
                 filename eq '' ? '' : ' - ', $
                 filename, $
                 format='(%"%s%s%s")')
  widget_control, self.tlb, base_set_title=title
end


;+
; Set the text in the status bar.
;
; :Params:
;   msg : in, optional, type=string
;     message to display in the status bar
;-
pro comp_db_browser::set_status, msg, clear=clear
  compile_opt strictarr

  _msg = keyword_set(clear) || n_elements(msg) eq 0L ? '' : msg
  widget_control, self.statusbar, set_value=_msg
end


pro comp_db_browser::_update_table, db_values
  compile_opt strictarr

  if (n_elements(db_values) eq 0L) then begin
    n_blank = 10
    widget_control, self.table, set_value=strarr(n_blank), $
                    xsize=n_blank, $
                    column_labels=strarr(n_blank)
  endif else begin
    widget_control, self.table, $
                    set_value=db_values, $
                    xsize=n_tags(db_values), $
                    column_labels=tag_names(db_values)
  endelse
end


function comp_db_browser::get_data
  compile_opt strictarr

  self->setProperty, database='MLSO'

  case self.current_instrument of
    'comp': self.current_table = keyword_set(self.current_engineering) ? 'comp_eng' : 'comp_img'
    'kcor': self.current_table = keyword_set(self.current_engineering) ? 'kcor_eng' : 'kcor_img'
  endcase

  return, self.db->query('select * from %s limit %s', $
                         self.current_table, self.current_limit)
end


;= widget events

pro comp_db_browser::handle_events, event
  compile_opt strictarr

  uname = widget_info(event.id, /uname)
  case uname of
    'tlb': begin
        tlb_geometry = widget_info(self.tlb, /geometry)
        table_geometry = widget_info(self.table, /geometry)
        statusbar_geometry = widget_info(self.statusbar, /geometry)

        table_width = event.x $
                        - 2 * tlb_geometry.xpad $
                        - 3
        statusbar_width = table_width
        height = event.y - 3 * tlb_geometry.ypad $
                   - statusbar_geometry.scr_ysize $
                   - 2 * statusbar_geometry.margin

        widget_control, self.tlb, update=0

        widget_control, self.table, scr_xsize=table_width, scr_ysize=height
        widget_control, self.statusbar, scr_xsize=statusbar_width

        widget_control, self.tlb, update=1
      end
    'instrument': begin
        self.current_instrument = strlowcase(event.str)
        self->_update_table, self->get_data()
      end
    'eng': begin
        self.current_engineering = 1B
        self->_update_table, self->get_data()
      end
    'images': begin
        self.current_engineering = 0B
        self->_update_table, self->get_data()
      end
    'limit': begin
        widget_control, event.id, get_value=limit_value
        self.current_limit = long(limit_value)
        self->_update_table, self->get_data()
      end
    else:
  endcase
end


;= widget lifecycle methods

;+
; Handle cleanup when the widget program is destroyed.
;-
pro comp_db_browser::cleanup_widgets
  compile_opt strictarr

  obj_destroy, self
end


pro comp_db_browser::create_widgets
  compile_opt strictarr

  table_xsize = 900
  table_ysize = 600
  xpad = 0

  self.tlb = widget_base(title=self.title, /column, /tlb_size_events, $
                         uvalue=self, uname='tlb')

  ; toolbar
  space = 10.0
  toolbar = widget_base(self.tlb, /row, uname='toolbar', /base_align_center)
  instrument_label = widget_label(toolbar, value='Instrument:')
  database_list = widget_combobox(toolbar, $
                                  value=['CoMP', 'KCor'], $
                                  uname='instrument')

  spacer = widget_base(toolbar, scr_xsize=space, xpad=0.0, ypad=0.0)

  type_label = widget_label(toolbar, value='Type:')
  type_base = widget_base(toolbar, xpad=0.0, ypad=0.0, /exclusive, /row)
  images_button = widget_button(type_base, value='images', uname='images')
  widget_control, images_button, /set_button
  engineering_button = widget_button(type_base, value='engineering data', uname='eng')

  spacer = widget_base(toolbar, scr_xsize=space, xpad=0.0, ypad=0.0)

  limit_label = widget_label(toolbar, value='Limit:')
  limit_text = widget_text(toolbar, value='500', uname='limit', $
                           scr_xsize=60.0, ysize=1, $
                           /editable)

  self.current_table = 'comp_img'
  self.current_instrument = 'comp'
  self.current_engineering = 0B

  db_values = self->get_data()


  self.table = widget_table(self.tlb, $
                            /no_row_headers, $
                            column_labels=tag_names(db_values[0]), $
                            value=db_values, $
                            xsize=n_tags(db_values[0]), $
                            scr_xsize=table_xsize, $
                            scr_ysize=table_ysize, $
                            uname='table', $
                            /resizeable_columns, $
                            /all_events, $
                            /context_events)
  self.statusbar = widget_label(self.tlb, $
                                scr_xsize=table_xsize + 2 * xpad, $
                                /align_left, /sunken_frame)
end


;+
; Draw the widget hierarchy.
;-
pro comp_db_browser::realize_widgets
  compile_opt strictarr

  widget_control, self.tlb, /realize
end


;+
; Start `XMANAGER`.
;-
pro comp_db_browser::start_xmanager
  compile_opt strictarr

  xmanager, 'comp_db_browser', self.tlb, /no_block, $
            event_handler='comp_db_browser_handleevents', $
            cleanup='comp_db_browser_cleanup'
end


;= property access

pro comp_db_browser::setProperty, database=database, table=table
  compile_opt strictarr

  if (n_elements(database) gt 0L) then begin
    self.current_database = database
    self.db->setProperty, database=database
  endif

  if (n_elements(table) gt 0L) then begin
    self.current_table = table
  endif
end



;= lifecycle methods

pro comp_db_browser::cleanup
  compile_opt strictarr

  obj_destroy, self.db
end


function comp_db_browser::init, config_filename, section=section
  compile_opt strictarr

  self.title = 'MLSO database browser'

  _config_filename = n_elements(config_filename) eq 0L $
                       ? filepath('.mysqldb', root=getenv('HOME')) $
                       : config_filename

  config = mg_read_config(_config_filename)

  config->getProperty, sections=sections

  _section = n_elements(section) eq 0L ? sections[0] : section

  obj_destroy, config

  self.current_limit = 500
  self.current_engineering = 0B

  self.db = mgdbmysql()
  self.db->setProperty, mysql_secure_auth=0
  self.db->connect, config_filename=_config_filename, $
                    config_section=_section, $
                    error_message=error_message
  self.db->getProperty, host_name=host

  self->create_widgets
  self->realize_widgets
  self->start_xmanager

  self->set_status, string(host, format='(%"Connected to %s...\n")')

  return, 1
end


pro comp_db_browser__define
  compile_opt strictarr

  define = { comp_db_browser, $
             title: '', $
             tlb: 0L, $
             db: obj_new(), $
             table: 0L, $
             statusbar: 0L, $
             current_database: '', $
             current_table: '', $
             current_limit: 0L, $
             current_instrument: '', $
             current_engineering: 0B $
           }
end


;+
; Browse the CoMP data in the MLSO database.
;
; :Params:
;   config_filename : in, optional, type=string, default=~/.mysqldb
;     configuration file with login information for database
;   section : in, optional, type=string
;     section of the configuration file to use; defaults to the first
;     section
;-
pro comp_db_browser, config_filename, section=section
  compile_opt strictarr
  on_error, 2

  browser = obj_new('comp_db_browser', config_filename, section=section)
end
