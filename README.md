# peaksight-binary-parser
kaitai_struct parser to read binary electron microprobe data files produced with Cameca Peaksight software

### Working example (for python as target language)
1. after downloading the repository, the file `peaksight_datafile_parser.ksy` needs to be compiled into target language with kaitai struct compiler.
   The "easiest" way is to go to kaitai struct webide, drag and drop the file to  web ide and right click on the file, then in the list `Generate parser` > and select the wished target language, which opens in the tab onto hexviewer part of ide. The code can be selected there and copied to a blank new file.
   Let's say we selected the python, had copied the code to new blank document in your favorite plain text/code editor, and saved the file as `cameca.py`.
   The alternative way is to install kaitai struct compiler and use CLI in the path of the file:
   `ksc -t python peaksight_datafile_parser.ksy`, which in the same directory produce the `cameca.py`.
2. the generated code depends from kaitai runtime libarary. In python You can install the required kaitai struct runtime with `python -m pip install kaitaistruct` (in some debian based systems, such as Ubuntu, if using python comming with OS You may need to use `python3` instead of `python`)
3. in python interpreter (or scripts) or jupyter notebook we can parse given data as this:
  ```python
  from cameca import Cameca
  
  k_spectra = Cameca.from_file('path_to_file.wdsDat')
  # to get to datasets:
  dts = k_spectra.sxf_main.datasets
  # if we want to print list of datasets with its setup name and comments:
  for i in dts:
     print(i.dts_header.setup_file_name.text, i.comment.text)
  ```
4. To know what is where in the object tree it is adviced to try parsing the binary files in kaitai web ide - it shows nice object tree, and it can be consulted for writting code in target language, albeit there will be some changes according to common practices in given language. I.e. python alows to access arguments directly in object, where most other languages will generate getters. Some languages changes lower case into Camel case (i.e. enumeration bundles as classes are renamed in python with CamelCase, while idividual enumeration values are left as is in ksy). Code completion, such as in jupyter notebooks can be also useful, while navigating inside the generated objects.

### Roadmap

- [x] make parser to read without throwing any errors any of below listed binary data:
  - [x] qtiDat
  - [x] wdsDat
  - [x] impDat
  - [x] calDat
  - [x] calSet
  - [x] qtiSet
  - [x] impSet
  - [x] wdsSet
  - [x] ovl
- [x] code deduplication and optimization (There needs to be achieved compromise. Duplicate structures can allow the resulting tree to be more flat (which is good when using in target language), where deduplication causes more deeper data tree, but is easier to maintain (which is good for maintaining the parser)) 
- [x] add language agnostic instancies for some attributes which can be prepared in language-agnostic way in kaitai struct
- [ ] add doc strings to explain further some halfly-parsed data
- [x] sanitize and stabilize the attribute names, so that third part software could use and do efortless drop-in updates
- [x] make huge data array binary strings subdivided into smaller binary strings representing a single image (frames in mosaiccing, or multi-acquisition mapping);
      return s list of binary strings (a string per frame)

### Limitations

While kaitai struct is awesome language-agnostic binary parsing framework, the language-agnosticity produces some limitations. Some data types are not universal between different languages, or built-in type(s) in some target languages has some not-wished side effects.
- data arrays for images and WDS scans are not parsed with correct datatype but returned as binary string. i.e. compilation to python (as one of main target languages) code does not use numpy arrays, the kaitai would convert numbers to native python number types and array would be returned as list, which in case of images would consume a lot of memory (as every number is an object in python with its attributes and methods).
- c# strings (in this kaitai code declared as `c_sharp_string`) has prepending 32 bit integer with lengh of the string, kaitai needs to read that before reading the string, and thus textual attributes contain one additional level. i.e. accessing comment of loaded parsed file would look like this: 

  ```python
   from somewhere_where_ksy_got_compiled_into_python_code.cameca import Cameca
   loaded_file = Cameca.from_file("at_some_path/some_stuff.qtiDat")
   print(loaded_file.sxf_header.comment.text)
  ```
  we need to use that additional `.text` argument (or a getter if used in other over-baby-sitting language compilation than python), as `.comment` is not a string type, but special `c_sharp_string` type with two attributes (or two private attributes and coresponding getters): `lenght` and `text`
- Some types does not has direct representation in all target languages. i.e. `FILETIME` or more precise `MS FILETIME`, which is parsed as 64-bit integer in the parser. It is intentended then either be cast into datetime(-like) type with built-in casting (i.e. C#) or use some custom function to convert it into standard unix timestamp.
