meta:
  id: cameca
  title: Cameca Peaksight binary data parser
  file-extension:
    - qtiDat
    - impDat
    - wdsDat
    - calDat
    - qtiSet
    - wdsSet
    - calSet
    - impSet
    - ovl
  endian: le
  license: LGPL-3.0-or-later
  ks-version: 0.9
  
doc: |
  This parser is created for reading the proprietary binary data formats
  produced with Cameca Peaksight software for EPMA.
  
  DISCLAIMERS
  This reverse engineering based implementation is granted by Petras Jokubauskas
  (klavishas@gmail.com; p.jokubauskas@uw.edu.pl).
  Author of this implementation is not affiliated with the Cameca or Ametek inc.
  Words, which by some parts could be recognized to be a trademark,
  are used in this file only for informative documentation of the code and
  it is not used for self-advertisement or criticism of rightful trademark holders.
  This reverse engineering pursuit is aimed for interoperability and
  such right is protected by EU directive 2009/24/EC.
  
  This RE-based implementation of formats is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  Lesser General Public License for more details.

seq:
  - id: sxf_header
    type: sxf_head
  - id: sxf_main
    type:
      switch-on: sxf_header.file_type
      cases:
        'file_type::wds_setup': wds_setup
        'file_type::image_mapping_setup': img_setup
        'file_type::calibration_setup': qti_cal_setup
        'file_type::quanti_setup': qti_cal_setup
        'file_type::wds_results': sxf_main
        'file_type::image_mapping_results': sxf_main
        'file_type::calibration_results': sxf_main
        'file_type::quanti_results': sxf_main
        'file_type::overlap_table': overlap_corrections

types:

  sxf_head:
    seq:
      - id: file_type
        type: u1
        enum: file_type
      - id: magic
        size: 3
        contents: fxs
      - id: sxf_version
        type: u4
      - id: comment
        type: c_sharp_string
      - id: reserved_0
        size: 0x1C
      - id: n_file_modifications
        type: u4
      - id: file_changes
        type: file_modification
        repeat: expr
        repeat-expr: n_file_modifications
      - id: reserved_v4
        size: 8
        if: sxf_version >= 4
      - id: reserved_v5
        type: f8
        if: sxf_version >= 5

  file_modification:
    seq:
      - id: datetime
        type: u8
        doc: "MS FILETIME type"
      - id: change
        type: c_sharp_string
        doc: |
          change is subdivided more by tabulation or special chars,
          proper subdivision should be implemented in target language as kaitai
          is good binary parser.

  c_sharp_string:
    seq:
      - id: str_len
        type: u4
      - id: text
        type: str
        size: str_len
        encoding: CP1252

  sxf_main:
    seq:
      - id: version
        type: u4
      - id: focus_frequency
        type: u4
      - id: verify_xtal_after_flip
        type: u4
      - id: verify_xtal_before_start
        type: u4
      - id: bkgd_measure_every_nth
        type: u4
      - id: decontamination_time
        type: u4
      - id: n_of_datasets
        type: u4
      - id: datasets
        type: dataset
        repeat: expr
        repeat-expr: n_of_datasets
      - id: not_re_global_options
        size: 12
      - id: current_qti_set
        type: c_sharp_string
      - id: not_re_global_options_2
        size: 216
      - id: not_re_global_options_v4
        size: 12
        if: _root.sxf_header.sxf_version >= 4
        
  dataset:
    doc: |
      Dataset is constructed form header, main and footer parts;
      in case of points in grid or line, main and footer parts are arrayed
      separately.
    seq:
      - id: dts_header
        type: dataset_header
      - id: dts_main
        type: data_common(dts_header.n_of_points)
        repeat: expr
        repeat-expr: dts_header.n_of_elements
      - id: comment
        type: c_sharp_string
      - id: reserved_0
        size: 32
      - id: extra_wds_meta_flag
        type: u4
      - id: extra_unknown
        type: wds_item_extra_ending  # what about other types?
        if: extra_wds_meta_flag == 1
      - id: template_flag
        type: u4
      - id: reserved_tmp_sector_0
        size: 8
        if: template_flag == 1
      - id: template
        type: dataset
        if: template_flag == 1
      - id: reserved_tmp_sector_1
        size: 4
        if: template_flag == 1
      - id: reserved_1
        size: 104
      - id: image_frames
        type: u4
        doc: |
          somehow images do not use n_accumulated, but this attribute;
          and profiles ignore this field (for profile it is filled 
          with value of previous item if it was img)
      - id: reserved_2
        size: 12
      - id: reserved_v18
        size: 4
        if: dts_header.version >= 0x12
      - id: footer_type
        type: u4
        enum: dts_footer_type
      - id: dts_footer
        type:
          switch-on: footer_type
          cases:
            'dts_footer_type::img_sec_footer': dts_img_sec_footer
            'dts_footer_type::wds_and_cal_footer': dts_wds_calib_footer
            'dts_footer_type::qti_v5_footer': dts_qti_footer(footer_type)
            'dts_footer_type::qti_v6_footer': dts_qti_footer(footer_type)
  
  dts_qti_footer:
    params:
      - id: footer_type
        type: u4
        enum: dts_footer_type
    seq:
      - id: reserved_0
        size: 4
      - id: n_space_time
        type: u4
      - id: datetime_and_pos
        type: space_time
        repeat: expr
        repeat-expr: n_space_time
      - id: reserved_1
        size: 4
      - id: qti_analysis_mode
        type: u4
        enum: analysis_mode
      - id: analysis_mode_info
        type:
          switch-on: qti_analysis_mode
          cases:
            'analysis_mode::by_stochiometry': stochiometry_info
            'analysis_mode::by_difference': by_difference_info
            'analysis_mode::matrix_def_and_stoch': matrix_definition_and_stoch_info
            'analysis_mode::with_matrix_definition': matrix_definition_info
            'analysis_mode::stoch_and_difference': stoch_and_difference_info
      - id: reserved_2
        size: 16
      - id: geo_species_name
        type: c_sharp_string
      - id: reserved_3
        size: 12
      - id: reserved_4
        size: 4
        if: footer_type == dts_footer_type::qti_v6_footer
      - id: mac_table
        type: embedded_mac_table
        if: footer_type == dts_footer_type::qti_v6_footer
  
  stochiometry_info:
    seq:
      - id: reserved_0
        size: 4
      - id: element_for_stochiometry
        type: u4
      - id: n_changed_oxy_states
        type: u4
      - id: oxy_state_changes
        type: element_oxy_state
        repeat: expr
        repeat-expr: n_changed_oxy_states
  
  by_difference_info:
    seq:
      - id: element_by_difference
        type: u4
  
  matrix_definition_info:
    seq:
      - id: reserved_0
        size: 4
      - id: n_elements
        type: u4
      - id: element_table
        type: element_weight
        repeat: expr
        repeat-expr: n_elements
      
  
  matrix_definition_and_stoch_info:
    seq:
      - id: reserved_0
        size: 4
      - id: element_for_stochiometry
        type: u4
      - id: n_changed_oxy_states
        type: u4
      - id: oxy_state_changes
        type: element_oxy_state
        repeat: expr
        repeat-expr: n_changed_oxy_states
      - id: reserved_2
        size: 4
      - id: n_elements
        type: u4
      - id: element_table
        type: element_weight
        repeat: expr
        repeat-expr: n_elements
        
  stoch_and_difference_info:
    seq:
      - id: reserved_0
        size: 4
      - id: element_for_stochiometry
        type: u4
      - id: n_changed_oxy_states
        type: u4
      - id: oxy_state_changes
        type: element_oxy_state
        repeat: expr
        repeat-expr: n_changed_oxy_states
      - id: element_by_difference
        type: u4
        
  embedded_mac_table:
    seq:
      - id: mac_name
        type: c_sharp_string
      - id: n_records
        type: u4
      - id: mac_table
        type: mac_record
        repeat: expr
        repeat-expr: n_records
        
  mac_record:
    seq:
      - id: absorbing_element
        type: u1
      - id: measured_element
        type: u1
      - id: xray_line
        type: u2
      - id: value
        type: f4
  
  dts_wds_calib_footer:
    seq:
      - id: reserved_0
        size: 4
        if: _root.sxf_header.file_type == file_type::calibration_results
      - id: n_space_time
        type: u4
        if: _root.sxf_header.file_type == file_type::calibration_results
      - id: datetime_and_pos
        type: space_time
        repeat: expr
        repeat-expr: |
          _root.sxf_header.file_type == file_type::calibration_results ?
          n_space_time : 1
      - id: reserved_1
        size:  4
      - id: reserved_wds_ending
        size: 48
        if: _root.sxf_header.file_type.to_i != 8
      - id: standard
        type: standard_composition_table
        if: _root.sxf_header.file_type.to_i == 8

  dataset_header:
    seq:
      - id: version
        type: u4
      - id: dataset_type
        type: u4
        enum: dataset_type
      - id: stage_x
        type: s4
      - id: stage_y
        type: s4
      - id: beam_x
        type: s4
      - id: beam_y
        type: s4
      - id: step_x
        type: f4
      - id: step_y
        type: f4
      - id: n_of_steps  # width
        type: u4
      - id: n_of_lines  # height
        type: u4
      - id: not_re_dataset_flags
        type: s4
        repeat: expr
        repeat-expr: 3
      - id: n_accumulation
        type: u4
      - id: dwell_time
        type: f4
      - id: not_re_dataset_flag_4
        type: s4
      - id: stage_z
        type: s4
        repeat: expr
        repeat-expr: 49
      - id: not_re_flags2  # TODO
        type: s4
        repeat: expr
        repeat-expr: 2
      - id: beam_measurement_freq
        type: f4
      - id: not_re_flags3
        type: s4
        repeat: expr
        repeat-expr: 2
      - id: mosaic_cols
        type: u4
      - id: mosaic_rows
        type: u4
      - id: focus_freq
        type: u4
      - id: load_setup_everyth_nth
        type: s4
      - id: not_re_flag4  # TODO
        type: s4
      - id: setup_file_name
        type: c_sharp_string
      - id: n_of_elements
        type: u4
    
    instances:
      n_of_points:
        value: n_of_steps * n_of_lines
      n_of_tiles:
        value: mosaic_cols * mosaic_rows
      is_mosaic:
        value: n_of_tiles > 1

  data_common:
    params:
      - id: n_points
        type: u4
    seq:
      - id: version
        type: u4
      - id: element_res_src
        type: u4
        enum: res_elem_src
      - id: signal_header
        size: 68
        type:
          switch-on: element_res_src
          cases:
            'res_elem_src::video': video_signal_header
            'res_elem_src::camera': empty_signal_header
            _: xray_signal_header
      - id: not_re_flag
        type: u4
      - id: reserved_0
        size: 12
      - id: n_of_reserved_1_blocks
        type: u4
      - id: reserved_1_blocks
        size: 12
        repeat: expr
        repeat-expr: n_of_reserved_1_blocks
      - id: signal
        type:
          switch-on: _root.sxf_header.file_type
          cases:
            'file_type::image_mapping_results': image_section_data
            'file_type::wds_results': wds_scan_data
            'file_type::quanti_results': qti_data(n_points)
            'file_type::calibration_results': calib_data
        
  xray_signal_header:
    seq:
      - id: atom_number
        type: u4
      - id: x_ray_line
        type: u4
        doc: |
          Kβ, Kα = 1, 2
          Lγ4, Lγ3, Lγ2, Lγ = 3, 4, 5, 6
          Lβ9, Lβ10, Lβ7, Lβ2, Lβ6, Lβ3, Lβ4, Lβ = range(7, 15)
          Lα, Lν, Ll = 15, 16, 17
          Mγ, Mβ, Mα, Mζ, Mζ2 = 18, 19, 20, 21, 22
          M1N2, M1N3, M2N1, M2N4, M2O4, M3N1, M3N4, M3O1, M3O4, M4O2 = range(23, 33)
          sKα1, sKα2, sKα3, sKα4, sKα5, sKα6, sKβ1 = range(100, 107)
      - id: order
        type: u4
      - id: spect_no
        type: u4
      - id: xtal4
        type: str
        size: 4
        encoding: ASCII
      - id: two_d
        type: f4
      - id: k
        type: f4
      - id: reserved_0
        size: 4
      - id: hv
        type: f4
      - id: current
        type: f4
      - id: peak_pos
        type: u4
      - id: counter_setting
        type: counter_setting
  
  counter_setting:
    seq:
      - id: bias
        type: u4
      - id: gain
        type: u4
      - id: dtime
        type: u4
      - id: blin
        type: u4
      - id: window
        type: u4
      - id: mode
        type: u4
        enum: pha_mode
        
  empty_signal_header:
    seq:
      - id: dummy
        size: 68
      
  video_signal_header:
    seq:
      - id: channel
        type: u4
      - id: signal
        type: u4
        enum: signal_type
      - id: padding_0
        size: 24
      - id: hv
        type: f4
      - id: current
        type: f4
      - id: padding_1
        size: 28
        
  image_section_data:
    seq:
      - id: struct_v
        type: u4
      - id: dts_t
        type: u4
        enum: dataset_type
      - id: stage_x
        type: s4
      - id: stage_y
        type: s4
      - id: beam_x
        type: s4
      - id: beam_y
        type: s4
      - id: step_x
        type: f4
      - id: step_y
        type: f4
      - id: width
        type: u4
      - id: height
        type: u4
      - id: z_axis
        type: s4
      - id: img_pixel_dtype
        type: u4
        enum: image_array_dtype
      - id: dwell_time
        type: f4
      - id: n_accumulation
        type: u4
        if: |
          (dts_t != dataset_type::line_stage) and
          (dts_t != dataset_type::line_beam)
      - id: not_re_flag
        type: u4
      - id: data_size
        type: u4
      - id: not_re_flag2
        type: u4
        if: |
          (dts_t != dataset_type::line_stage) and
          (dts_t != dataset_type::line_beam)
      - id: not_re_flag3
        type: f4
        if: |
          (dts_t != dataset_type::line_stage) and
          (dts_t != dataset_type::line_beam)
      - id: not_re_flag4
        type: f4
        if: |
          (dts_t != dataset_type::line_stage) and
          (dts_t != dataset_type::line_beam)
      - id: data
        size: frame_size
        repeat: expr
        repeat-expr: n_of_frames
        doc: |
          list of arrays, where if mosaic: every item is bytestring from
          one tile; else if multi-frame picture (multiple-overscan) then
          average or sum (depending what set in GUI) of all frames, indexes
          1 to end subframes.
      - id: reserved_0 # Somethere here begins LUT and color bar description
        size: 56
      - id: lut_name
        type: c_sharp_string
      - id: signal_name
        type: c_sharp_string
      - id: intensity_min
        type: f4
      - id: intensity_max
        type: f4
      - id: reserved_1  # maybe it is x,y origin position
        size: 20
      - id: visible_width
        type: u4
      - id: visible_height
        type: u4
      - id: colorbar_ticks
        type: color_bar_ticks
      - id: img_rotation
        type: f4
      - id: reserved_2
        size: 8
        
    instances:
      frame_size:
        value: (img_pixel_dtype.to_i == 0 ? 1 : 4) * _parent._parent.dts_header.n_of_points
      n_of_frames:
        value: data_size / frame_size
  
  color_bar_ticks:
    seq:
      - id: n_color_bar_ticks
        type: u4
      - id: colors
        type: color_tick
        repeat: expr
        repeat-expr: n_color_bar_ticks
        if: n_color_bar_ticks > 0
      - id: max_value
        type: f4
        if: n_color_bar_ticks > 0
      - id: reserved_0
        type: f4
      - id: reserved_1
        size: 4
      - id: n_color_bar_labels
        type: u4
      - id: custom_color_bar_labels
        type: bar_label
        repeat: expr
        repeat-expr: n_color_bar_labels
        if: n_color_bar_labels > 0
  
  color_tick:
    seq:
      - id: color
        type: u4
      - id: l_value
        type: f4
  
  bar_label:
    seq:
      - id: sec_name
        type: c_sharp_string
      - id: reserved_0
        size: 40

  calib_data:
    seq:
      - id: version
        type: u4
      - id: data_size
        type: u4
      - id: unkn_x
        size: 4
      - id: total_size
        type: u4
      - id: data_list
        size: total_size
      - id: calib_peak_time
        type: f4
      - id: calib_bkgd_time
        type: f4
      - id: bkgd_1_pos
        type: s4
      - id: bkgd_2_pos
        type: s4
      - id: bkgd_slope
        type: f4
      - id: quanti_mode
        type: u4
        enum: quanti_mode
      - id: pk_area_range
        type: u4
      - id: pk_area_channels
        type: u4
      - id: pk_area_bkgd_1
        type: s4
      - id: pk_area_bkgd_2
        type: s4
      - id: pk_area_n_accumulation
        type: u4
      - id: not_re_area_flags
        size: 24
      - id: n_calib_points
        type: u4
      - id: pk_area_wds_spetras
        type: quanti_wds_scan
        repeat: expr
        repeat-expr: n_calib_points

  qti_data:
    params:
      - id: n_steps
        type: u4
    seq:
      - id: version
        type: u4
      - id: dts_t
        type: u4
        enum: dataset_type
      - id: data_size
        type: u4
      - id: data
        type: qti_data_item
        repeat: expr
        repeat-expr: n_steps
      - id: reserved_0
        type: u4
      - id: standard_name
        type: c_sharp_string
      - id: n_elements_standard
        type: u4
      - id: standard_weight_table
        type: element_weight
        repeat: expr
        repeat-expr: n_elements_standard
      - id: calib_hv
        type: f4
      - id: calib_current
        type: f4
      - id: i_standard
        type: f4
      - id: i_standard_std  #TODO is it ???? huh???
        type: f4
      - id: calibration_file_name
        type: c_sharp_string
      - id: calib_peak_time
        type: f4
      - id: calib_bkgd_time
        type: f4
      - id: bkgd_1_pos
        type: s4
      - id: bkgd_2_pos
        type: s4
      - id: bkgd_slope
        type: f4
      # below have something to do with WDS in scan quantification method:
      - id: quanti_mode
        type: u4
        enum: quanti_mode
      - id: pk_area_range
        type: u4
      - id: pk_area_channels
        type: u4
      - id: pk_area_bkgd_1
        type: s4
      - id: pk_area_bkgd2
        type: s4
      - id: pk_area_n_accumulation
        type: u4
      - id: not_re_pk_area_flags
        size: 36
      - id: n_of_embedded_wds
        type: u4
      - id: pk_area_wds_spetras
        type: quanti_wds_scan
        repeat: expr
        repeat-expr: n_of_embedded_wds
      - id: not_re_calib_block
        size: 8
        if: _root.sxf_header.sxf_version > 3
      
  element_weight:
    seq:
      - id: element
        type: u4
      - id: weight_fraction
        type: f4
        
  element_oxy_state:
    seq:
      - id: element
        type: u4
      - id: oxy_state
        type: f4
        
  wds_scan_data:
    seq:
      - id: version
        type: u4
      - id: wds_start_pos
        type: u4
      - id: steps
        type: u4
      - id: step_size
        type: f4
      - id: dwell_time
        type: f4
      - id: beam_size #TODO is it?
        type: u4
      - id: data_array_size
        type: u4
      - id: data
        size: data_array_size
      - id: not_re_flag
        type: u4
      - id: signal_name
        type: c_sharp_string
      - id: reserved_0  # probably curve parameters
        size: 4
      - id: smoothing_pts
        type: u4
      - id: min_x  # sin theta * 10000
        type: f4
      - id: max_x
        type: f4
      - id: min_y
        type: f4
      - id: max_y
        type: f4
      - id: curve_color
        size: 4
      - id: reserved_1
        size: 8
      - id: curve_type
        type: u4 # 2 is solid line
      - id: curve_width
        type: u4
      - id: reserved_2
        size: 4
      - id: lut_name
        type: c_sharp_string
      - id: reserved_3
        size: 52
      - id: n_of_annot_lines
        type: u4
      - id: annotated_lines_table
        type: annotated_lines
        repeat: expr
        repeat-expr: n_of_annot_lines
      - id: reserved_4
        size: 4
      - id: extra_ending_flag
        type: u4
      - id: extra_ending
        type: wds_item_extra_ending
        if: extra_ending_flag == 1
  
  quanti_wds_scan:
    seq:
      - id: version #?
        type: u4
      - id: n_channels
        type: u4
      - id: start_pos
        type: f4
        if: n_channels > 0
      - id: step
        type: f4
        if: n_channels > 0
      - id: dwell_time
        type: f4
        if: n_channels >0
      - id: data
        size: n_channels * 4  #x4 as 32bit
        if: n_channels > 0
  
  wds_item_extra_ending:
    seq:
      - id: item_comment
        type: c_sharp_string
      - id: not_re_flag_0
        type: f4
      - id: not_re_flag_1
        type: s4
      - id: not_re_flag_2
        type: s4
      - id: color
        size: 4
      - id: not_re_flag_3
        type: f4
      - id: not_re_flag_4
        type: f4
      - id: not_re_falg_5
        size: 16
        
  
  annotated_lines:
    seq:
      - id: element
        type: u4
      - id: line
        type: u4
        doc: |
          Kβ, Kα = 1, 2
          Lγ4, Lγ3, Lγ2, Lγ = 3, 4, 5, 6
          Lβ9, Lβ10, Lβ7, Lβ2, Lβ6, Lβ3, Lβ4, Lβ = range(7, 15)
          Lα, Lν, Ll = 15, 16, 17
          Mγ, Mβ, Mα, Mζ, Mζ2 = 18, 19, 20, 21, 22
          M1N2, M1N3, M2N1, M2N4, M2O4, M3N1, M3N4, M3O1, M3O4, M4O2 = range(23, 33)
          sKα1, sKα2, sKα3, sKα4, sKα5, sKα6, sKβ1 = range(100, 107)
      - id: order
        type: u4
      - id: reserverd1
        type: u4
      - id: reserverd2
        type: u4
   
  qti_data_item:
    seq:
      - id: version
        type: u4
      - id: fara_meas
        type: f4
      - id: peak_cps
        type: f4
      - id: peak_time
        type: f4
      - id: bkgd_under_peak_cps
        type: f4
      - id: bkgd_1_cps
        type: f4
      - id: bkgd_2_cps
        type: f4
      - id: ix_div_istd
        type: f4
      - id: ix_div_ipure
        type: f4
      - id: weight_fraction
        type: f4
      - id: normalised_weight_f
        type: f4
      - id: atomic_fraction
        type: f4
      - id: oxide_fraction
        type: f4
      - id: detection_limit
        type: f4
      - id: standard_deviation
        type: f4
      - id: z
        type: f4
      - id: a
        type: f4
      - id: f
        type: f4
      - id: not_re_1
        type: u4
      - id: not_re_2
        type: f4
      - id: not_re_3
        type: f4
      - id: peak_raw_pulses
        type: u4
      - id: bkgd_1_raw_pulses
        type: u4
      - id: bkgd_2_raw_pulses
        type: u4
      - id: subcounting_mode
        type: u4
        enum: subcounting_mode
      - id: n_sub_count
        type: u4
      - id: subcount_peak_enabled_flags
        type: u4
      - id: subcount_peak_pulses
        type: u4
        repeat: expr
        repeat-expr: n_sub_count
      - id: padding_0
        size: (30 - n_sub_count) * 4  # 30 is maximum number of subcounts
      - id: reserved_0
        size: 4
      - id: subcount_bkgd1_enabled_flags
        type: u4
      - id: subcount_bkgd1_pulses
        type: u4
        repeat: expr
        repeat-expr: n_sub_count
      - id: padding_1
        size: (30 - n_sub_count) * 4
      - id: subcount_bkgd2_enabled_flags
        type: u4
      - id: subcount_bkgd2_pulses
        type: u4
        repeat: expr
        repeat-expr: n_sub_count
      - id: padding_2
        size: (30 - n_sub_count) * 4
      - id: bkgd_time
        type: f4
      - id: padding_v11
        size: 8
        if: version >= 11

  image_data:
    seq:
      - id: n_accumulation
        type: u4
      - id: not_re_flag_0
        type: u4
      - id: data_size
        type: u4
      - id: not_re_flag_1
        type: u4
      - id: not_re_flag_2
        type: u4
      - id: not_re_flag_3
        type: f4
      - id: data
        size: data_size - 12

  dts_img_sec_footer:
    seq:
      - id: datetime_and_pos
        type: space_time
      - id: reserved_0
        size:  4
      - id: reserved_1
        size: 8
      - id: reserved_2
        size: 64
      - id: n_subsections
        type: u4
      - id: subsections
        type: img_footer_subsection
        repeat: expr
        repeat-expr: n_subsections
  
  space_time:
    doc: |
      this struct allways contains valid datetime;
      If dataset is composed from multiple items this struct
      also will contain valid x,y and z stage coordinates;
      otherwise often those attributes here are zeros.
      Also this section holds calculated age and 1sigma error, if
      age calculation was done and saved with peaksight.
    seq:
      - id: version
        type: u4
      - id: datetime
        type: u8
        doc: 'MS FILETIME'
      - id: x_axis
        type: f4
      - id: y_axis
        type: f4
      - id: z_axis
        type: f4
      - id: reserved_0
        size: 8
      - id: not_re_0
        type: u4
      - id: age
        type: f4
      - id: age_err
        type: f4
      - id: reserved_1
        size: 56
      - id: reserved_v6
        size: 24
        if: version == 6

  img_footer_subsection:
    seq:
      - id: phase_something_str
        type: c_sharp_string
      - id: reserved_0
        size: 300
      - id: mosaic_rows
        type: u4
      - id: mosaic_cols
        type: u4
      - id: mosaic_segment_enabled_flag_array
        type: s1
        repeat: expr
        repeat-expr: mosaic_rows * mosaic_cols
        doc: |
          some flags (older format?) are 0x01;
          newer format are 0x03 (?);
          I am not sure that there are no -1, thus type is signed integer
          as for now;
        
  standard_composition_table:
    seq:
      - id: standard_name
        type: c_sharp_string
      - id: n_elements
        type: u4
      - id: standard_weight_table
        type: element_weight
        repeat: expr
        repeat-expr: n_elements

  overlap_corrections:
    seq:
      - id: reserved_0
        size: 4
      - id: n_corrections
        type: u4
      - id: overlap_correction_table
        type: overlap_table_item
        repeat: expr
        repeat-expr: n_corrections
        
  overlap_table_item:
    seq:
      - id: version
        type: u4
      - id: element
        type: u4
      - id: line
        type: u4
      - id: i_element
        type: u4
      - id: i_line
        type: u4
      - id: i_order
        type: u4
      - id: i_offset
        type: s4
      - id: hv
        type: f4
      - id: beam_current
        type: f4
      - id: peak_min_bkgd
        type: f4
      - id: standard_name
        type: c_sharp_string
      - id: nr_in_standard_db
        type: u4
      - id: spect_nr
        type: u4
      - id: rev_xtal_name
        size: 4
      - id: dwell_time
        type: f4
        if: version >= 3
      - id: reserved_0
        size: 4
  
  img_setup:
    doc: this is roughly RE and far from complete
    seq:
      - id: reserved_0
        size: 12
      - id: n_sub_setups
        type: u4
      - id: subsetups
        type: sub_setup
        repeat: expr
        repeat-expr: n_sub_setups
  
  qti_cal_setup:
    doc: this is a rought reverse engineared and far from complete
    seq:
      - id: reserved_0
        size: 12
      - id: n_sub_setups
        type: u4
      - id: subsetups
        type: sub_setup
        repeat: expr
        repeat-expr: n_sub_setups
      - id: reserved_1
        size: 28
      - id: qti_analysis_mode
        type: u4
        enum: analysis_mode
      - id: analysis_mode_info
        type:
          switch-on: qti_analysis_mode
          cases:
            'analysis_mode::by_stochiometry': stochiometry_info
            'analysis_mode::by_difference': by_difference_info
            'analysis_mode::matrix_def_and_stoch': matrix_definition_and_stoch_info
            'analysis_mode::with_matrix_definition': matrix_definition_info
            'analysis_mode::stoch_and_difference': stoch_and_difference_info
      - id: reserved_2
        size: 16
      - id: geo_species_name
        type: c_sharp_string
      - id: reserved_3
        size: 4
      - id: reserved_v20
        size: 140
        if: _root.sxf_header.sxf_version >= 5

  wds_setup:
    doc: this is roughly reverse engineared and far from complete
    seq:
      - id: reserved_0
        size: 12
      - id: wds_scan_spect_setups
        type: wds_scan_spect_setup
        repeat: expr
        repeat-expr: 5
      - id: column_and_sem_setup
        type: sub_setup
        
  sub_setup:
    doc: this is a rought reverse engineared and far from complete
    seq:
      - id: version
        type: u4
      - id: reserved_0
        size: 4
      - id: condition_name
        type: c_sharp_string
      - id: reserved_1
        size: 20
      - id: heat
        type: u4
        doc: fixed point as integer
      - id: hv
        type: u4
      - id: i_emission
        type: u4
      - id: xhi
        type: s4
      - id: yhi
        type: s4
      - id: xlo
        type: s4
      - id: ylo
        type: s4
      - id: aperture_x
        type: s4
      - id: aperture_y
        type: s4
      - id: c1
        type: u4
      - id: c2
        type: u4
      - id: reserved_2
        size: 4
      - id: current_set
        type: s4
      - id: beam_focus
        type: s4
      - id: reserved_3
        type: s4
      - id: reserved_4
        type: s4
      - id: beam_focus_2
        type: s4
      - id: beam_size
        type: s4
      - id: stigmator_amplitude
        type: s4
      - id: stigmator_angle
        type: s4
      - id: reserved_flags_5
        type: s4
        repeat: expr
        repeat-expr: 6
      - id: extractor
        type: s4  # TODO is it?
      - id: suppressor
        type: s4
      - id: reserved_flags_6
        type: s4
        repeat: expr
        repeat-expr: |
          _root.sxf_header.file_type.to_i > 1 ? 86 : 85
      - id: n_eds_measurement_setups
        type: u4
        if: _root.sxf_header.file_type.to_i > 1
      - id: eds_measurement_setups
        type: qti_eds_measurement_setup
        repeat: expr
        repeat-expr: n_eds_measurement_setups
        if: _root.sxf_header.file_type.to_i > 1
      - id: default_eds_live_time
        type: f4
      - id: not_re_flag_5
        type: u4
      - id: eds_roi_fwhm
        type: f4
      - id: reserved_flags_7
        size: 8
      - id: wds_measurement_struct_type
        type: u4
        if: _root.sxf_header.file_type.to_i > 1
      - id: wds_img_spect_setups
        type: img_wds_spect_setups
        if: wds_measurement_struct_type == 3
      - id: wds_qti_measurement_setups
        type: qti_wds_measurement_setups
        if: wds_measurement_struct_type >= 19
  
  wds_scan_spect_setup:
    seq:
      - id: rev_xtal_string
        size: 4
      - id: two_d
        type: f4
      - id: k
        type: f4
      - id: wds_scan_type
        type: u4
        enum: wds_scan_type
      - id: min_pos
        type: u4
      - id: reserved_1
        type: u4
      - id: reserved_2
        type: u4
      - id: reserved_3
        type: u4
      - id: max_pos
        type: u4
      - id: reserved_4
        size: 4 * 3
      - id: position
        type: u4
      - id: element
        type: u4
      - id: line
        type: u4
      - id: order # TODO is it????
        type: u4
      - id: offset_1
        type: s4
      - id: offset_2
        type: s4
      - id: counter_setting
        type: counter_setting
  
  img_wds_spect_setups:
    seq:
      - id: wds_img_spect_setup_table
        type: img_wds_spect_setup
        repeat: expr
        repeat-expr: 5
        
  qti_wds_measurement_setups:
    seq:
      - id: qti_setup_reserved_0
        size: 20
      - id: n_wds_measurements
        type: u4
      - id: qti_wds_measurement_setups
        type: qti_wds_measurement_setup
        repeat: expr
        repeat-expr: n_wds_measurements
        
  
  img_wds_spect_setup:
    seq:
      - id: rev_xtal_string
        size: 4
      - id: two_d
        type: f4
      - id: k
        type: f4
      - id: peak_position
        type: u4
      - id: element
        type: u4
      - id: line
        type: u4
      - id: order
        type: u4  #TODO check if it is true
      - id: counter_setting
        type: counter_setting
      - id: padding_0
        size: 12
  
  qti_eds_measurement_setup:
    seq:
      - id: reserved_0
        type: u4
      - id: element
        type: u4
      - id: line
        type: u4
      - id: reserved_1
        size: 12
      
  
  qti_wds_measurement_setup:
    seq:
      # TODO Where is line order?
      - id: element
        type: u4
      - id: line
        type: u4
      - id: spect_number
        type: u4
      - id: rev_xtal_name
        type: s4
      - id: not_re_flag_0
        type: f4
      - id: not_re_flag_1
        type: f4
      - id: calibration_file
        type: c_sharp_string
      - id: reserved_0  # Is order in this?
        size: 12
      - id: peak_position
        type: u4
      - id: peak_time
        type: f4
      - id: offset_bkgd_1
        type: s4
      - id: offset_bkgd_2
        type: s4
      - id: slope
        type: f4
      - id: bkgd_time
        type: f4
      - id: counter_setting
        type: counter_setting
      - id: one_div_sqrt_n
        type: f4
      - id: reserved_1
        size: 12
      - id: background_type
        type: u4
        enum: background_type
      - id: reserved_2
        size: 180
      - id: subcounting_flag
        type: u4
        enum: subcounting_mode
      - id: reserved_3
        size: 156
      - id: reserved_v4
        size: 4
        if: _root.sxf_header.sxf_version >= 4


enums:
  file_type:
    1: wds_setup
    2: image_mapping_setup
    3: calibration_setup
    4: quanti_setup
    # what is 5?
    6: wds_results
    7: image_mapping_results
    8: calibration_results
    9: quanti_results
    10: overlap_table
    
  quanti_mode:
    0: area
    1: peak_background

  dataset_type:
    0: point
    1: line_stage
    2: line_beam
    3: grid_stage
    4: grid_beam
    5: polygon_masked_stage_raster
    6: polygon_masked_beam_raster
    7: free_points
    
  res_elem_src:
    # exposed in GUI as drop-down menu, thanks!
    0: undefined
    1: wds
    2: eds
    3: video
    4: other
    5: qti_diff
    6: qti_stoch
    7: qti_matrix
    8: imove
    9: imphcl
    10: im_phid
    11: imqti_wds_bkgd_meas
    12: imqti_wds_bkgd_computed
    13: imqti_wt
    14: imqti_at
    15: imqti_sum
    16: imqti_age
    17: imqti_oxy
    18: imxon_video
    19: camera
    20: wds_computed
    21: eds_bkgd
  
  pha_mode:
    0: integral
    1: differential
    2: differential_auto
    
  signal_type:
    0: se
    1: fara
    2: bse  # 0x02 as BSE is on SX100, but not on SXFive
    3: abs
    # 4?
    5: cl
    0x3F000002: bse_z  # BSE Z on SxFive
    0x38070002: bse_t  # all signal types with lowest bits as 0x02 are BSE?
    0x30000002: bse_1
    0x18000002: bse_2
    0x06000002: bse_3
    0x03000002: bse_4
    0x0C000002: bse_5
  
  image_array_dtype:
    0: uint8
    #what is 1-6?
    7: float32
    8: rgbx
    
  dts_footer_type:
    #1: ?
    2: wds_and_cal_footer # why it is the same for so different stuff?
    #3:?
    4: qti_v5_footer #peaksight 5
    5: img_sec_footer
    6: qti_v6_footer
    
  analysis_mode:
    0: all
    1: by_stochiometry
    2: by_difference
    3: stoch_and_difference
    4: with_matrix_definition
    #5-6 ???
    7: matrix_def_and_stoch
    
  subcounting_mode:
    0: none
    1: subcounting_p_b_p_b
    2: subcounting_p_p_b_b
    3: time_0_intercept
    4: decontamination_auto_test
    5: chi_square_test
    6: sub_chi_p_b_p_b
    7: sub_chi_p_p_b_b
  
  background_type:
    1: linear
    2: exponential
    
  wds_scan_type:
    0: full
    1: relative
    2: absolute
    
