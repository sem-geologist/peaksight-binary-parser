# peaksight-binary-parser
kaitai_struct parser to read binary electron microprobe data files produced with Cameca Peaksight software

### Roadmap

- [ ] make parser to read without throwing any errors any of below listed binary data:
  - [x] qtiDat
  - [x] wdsDat
  - [x] impDat
  - [x] calDat
  - [x] calSet
  - [x] qtiSet
  - [x] impSet
  - [ ] wdsSet
  - [ ] ovl
- [ ] code deduplication and optimization (There needs to be achieved compromise. Duplicate structures can allow the resulting tree to be more flat (which is good when using in target language), where deduplication causes more deeper data tree, but is easier to maintain (which is good for maintaining the parser)) 
- [ ] add language agnostic instancies for some attributes which can be prepared in language-agnostic way in kaitai struct
- [ ] add doc strings to explain further some halfly-parsed data
- [ ] sanitize and stabilize the attribute names, so that third part software could use and do efortless drop-in updates
- [ ] could huge data array binary strings subdivided into smaller binary strings representing a single run (in multi-run wds) / image (in mosaiccing, or multi-run mapping)?

### Limitations

While kaitai struct is awesome language-agnostic binary parsing framework, the language-agnosticity produces some limitations. Some data types are not universal between different languages, or built-in type(s) in some target languages has some not-wished side effects.
- data arrays for images and WDS scans are not parsed with correct datatype but returned as binary string. i.e. compilation to python (as one of main target languages) code does not use numpy arrays, the kaitai would convert numbers to native python number types and array would be returned as list, which in case of images would consume a lot of memory (as every number is an object in python with its attributes and methods).
- c# strings (in this kaitai code declared as `c_sharp_string`) has prepending 32 bit integer with lengh of the string, kaitai needs to read that before reading the string, and thus textual attributes contain one additional level. i.e. accessing comment of loaded parsed file would look like this: 

  ```python
   from somewhere_where_ksy_got_compiled_into_python_code import cameca
   loaded_file = cameca.from_file("at_some_path/some_stuff.qtiDat")
   print(loaded_file.sxf_header.comment.text)
  ```
  we need to use that additional `.text` argument (or a getter if used in other over-baby-sitting language compilation than python), as `.comment` is not a string type, but special `c_sharp_string` type with two attributes (or two private attributes and coresponding getters): `lenght` and `text`
- Some types does not has direct representation in all target languages. i.e. `FILETIME` or more precise `MS FILETIME`, which is parsed as 64-bit integer in the parser. It is intentended then either be cast into datetime(-like) type with built-in casting (i.e. C#) or use some custom function to convert it into standard unix timestamp.
