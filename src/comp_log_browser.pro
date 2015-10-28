; docformat = 'rst'


;= helper routines

;+
; Thin procedural wrapper to call `::handle_events` event handler.
;
; :Params:
;    event : in, required, type=structure
;       event structure for event handler to handle
;-
pro comp_log_browser_handleevents, event
  compile_opt strictarr

  widget_control, event.top, get_uvalue=browser
  browser->handle_events, event
end


;+
; Thin procedural wrapper to call `::cleanup_widgets` cleanup routine.
;
; :Params:
;    tlb : in, required, type=long
;       top-level base widget identifier
;-
pro comp_log_browser_cleanup, tlb
  compile_opt strictarr

  widget_control, tlb, get_uvalue=browser
  if (obj_valid(browser)) then browser->cleanup_widgets
end


pro comp_log_browser::_load_text_file, filename, text_widget
  compile_opt strictarr

  if (~file_test(filename)) then return

  n_lines = file_lines(filename)
  text = strarr(n_lines)
  openr, lun, filename, /get_lun
  readf, lun, text
  free_lun, lun

  widget_control, text_widget, set_value=text
end


;+
; Set the window title based on the current filename. Set the filename to the
; empty string if there is no title to display.
;
; :Params:
;    filename : in, required, type=string
;       filename to display in title
;-
pro comp_log_browser::set_title, filename
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
pro comp_log_browser::set_status, msg, clear=clear
  compile_opt strictarr

  _msg = keyword_set(clear) || n_elements(msg) eq 0L ? '' : msg
  widget_control, self.statusbar, set_value=_msg
end


pro comp_log_browser::load_directory, dir
  compile_opt strictarr

  if (file_test(dir, /directory)) then begin
    ; find available dates
    cidx_logs = file_search(filepath('*.log', subdir='cidx', root=dir), count=n_logs)
    dates = strmid(file_basename(cidx_logs), 0, 8)
    widget_control, self.list, set_value=dates

    ; store state
    *self.dates = dates
    self.log_dir = dir
  endif
end


pro comp_log_browser::load_observer_directory, dir
  compile_opt strictarr

  if (file_test(dir, /directory)) then begin
    self.obs_log_dir = dir
  endif
end



;= event handling

;+
; Handle all events from the widget program.
;
; :Params:
;    event : in, required, type=structure
;       event structure for event handler to handle
;-
pro comp_log_browser::handle_events, event
  compile_opt strictarr

  uname = widget_info(event.id, /uname)
  case uname of
    'tlb': begin
        ; TODO: implement resizing
    end
    'list': begin
        date = (*self.dates)[event.index]
        cidx_log_filename = filepath(date + '.log', subdir='cidx', root=self.log_dir)

        self->_load_text_file, cidx_log_filename, self.cidx_text

        ; load observer log, if possible
        if (self.obs_log_dir ne '') then begin
          year = strmid(date, 0, 4)
          month = strmid(date, 4, 2)
          day = strmid(date, 6, 2)
          doy = mg_ymd2doy(long(year), long(month), long(day))

          obs_basename = string(year, doy, format='(%"mlso.%sd%03d.olog")')
          obs_log_filename = filepath(obs_basename, subdir=year, root=self.obs_log_dir)

          self->_load_text_file, obs_log_filename, self.obs_text
        endif
      end
    else:
  endcase
end


;= widget lifecycle methods

;+
; Handle cleanup when the widget program is destroyed.
;-
pro comp_log_browser::cleanup_widgets
  compile_opt strictarr

  obj_destroy, self
end


;+
; Create the widget hierarchy.
;-
pro comp_log_browser::create_widgets
  compile_opt strictarr

  self.tlb = widget_base(title=self.title, /column, /tlb_size_events, $
                         uvalue=self, uname='tlb')
  
  ; toolbar
  bitmapdir = ['resource', 'bitmaps']
  toolbar = widget_base(self.tlb, /toolbar, /row, uname='toolbar', xpad=0)

  file_toolbar = widget_base(toolbar, /toolbar, /row, xpad=0)
  open_button = widget_button(file_toolbar, /bitmap, uname='open', $
                              tooltip='Open FITS file', $
                              value=filepath('open.bmp', subdir=bitmapdir))

  ; content row
  content_base = widget_base(self.tlb, /row, xpad=0)

  list_xsize = 125
  text_xsize = 850
  scr_ysize = 600
  xpad = 0

  self.list = widget_list(content_base, uname='list', $
                          scr_xsize=list_xsize, scr_ysize=scr_ysize)

  tabs = widget_tab(content_base, uname='tabs')

  cidx_base = widget_base(tabs, xpad=0, ypad=0, title='Run log', /column)
  self.cidx_text = widget_text(cidx_base, value='', uname='cidx', $
                               scr_xsize=text_xsize, scr_ysize=scr_ysize, $
                               /scroll)

  obs_base = widget_base(tabs, xpad=0, ypad=0, title='Observer log', /column)
  self.obs_text = widget_text(obs_base, value='', uname='obs', $
                              scr_xsize=text_xsize, scr_ysize=scr_ysize, $
                              /scroll)

  ; status bar
  self.statusbar = widget_label(self.tlb, $
                                scr_xsize=list_xsize + text_xsize + 2 * 4.0, $
                                /align_left, /sunken_frame)
end


;+
; Draw the widget hierarchy.
;-
pro comp_log_browser::realize_widgets
  compile_opt strictarr

  widget_control, self.tlb, /realize
end


;+
; Start `XMANAGER`.
;-
pro comp_log_browser::start_xmanager
  compile_opt strictarr

  xmanager, 'comp_log_browser', self.tlb, /no_block, $
            event_handler='comp_log_browser_handleevents', $
            cleanup='comp_log_browser_cleanup'
end


pro comp_log_browser::cleanup
  compile_opt strictarr

  ptr_free, self.dates
end


function comp_log_browser::init
  compile_opt strictarr

  self.title = 'CoMP log browser'

  self->create_widgets
  self->realize_widgets
  self->start_xmanager

  self.dates = ptr_new(/allocate_heap)

  self->set_status, 'Ready'

  return, 1
end


pro comp_log_browser__define
  compile_opt strictarr

  define = { comp_log_browser, $
             tlb: 0L, $
             statusbar: 0L, $
             list: 0L, $
             cidx_text: 0L, $
             obs_text: 0L, $
             dates: ptr_new(), $
             log_dir: '', $
             obs_log_dir: '', $
             title: '' $
           }
end


pro comp_log_browser, log_dir, observer_log_dir=observer_log_dir
  compile_opt strictarr
  on_error, 2
  common comp_log_browser, browser

  if (n_elements(log_dir) eq 0L) then begin
    message, 'log directory not specified'
  endif

  if (~obj_valid(browser)) then begin
    browser = obj_new('comp_log_browser')
  endif

  browser->load_directory, log_dir

  if (n_elements(observer_log_dir)) then begin
    browser->load_observer_directory, observer_log_dir
  endif
end