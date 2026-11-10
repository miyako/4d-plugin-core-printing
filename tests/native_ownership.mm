#include "4DPluginAPI.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>

// Only the engine boundary is simulated; all PA_* functions come from the
// complete, unchanged bundled SDK translation unit.
static std::set<PA_Unichar *> strings;
static std::map<PA_Handle, size_t> handles;
struct SyntheticPicture { unsigned refs; };
static std::set<SyntheticPicture *> pictures;
static bool nullEmpty;
static bool replacePicture;
static CUTF16String expectedText;

static void require(bool condition, const char *message)
{
    if (!condition) {
        std::fprintf(stderr, "ownership regression: %s\n", message);
        std::exit(1);
    }
}

static PA_Unistring makeString(const PA_Unichar *text)
{
    size_t length = 0;
    if (text) while (text[length]) ++length;
    PA_Unistring value = {};
    value.fLength = static_cast<PA_long32>(length);
    if (length || !nullEmpty) {
        value.fString = new PA_Unichar[length + 1];
        if (length) std::memcpy(value.fString, text, length * sizeof(PA_Unichar));
        value.fString[length] = 0;
        PA_Unichar *buffer = value.fString;
        require(strings.insert(buffer).second, "unique string allocation");
    }
    return value;
}

static void disposeString(PA_Unistring value)
{
    if (!value.fString) {
        require(value.fLength == 0, "null string is empty");
        return;
    }
    PA_Unichar *buffer = value.fString;
    require(strings.erase(buffer) == 1, "double disposal or borrowed string disposal");
    delete[] value.fString;
}

static void checkString(PA_Unistring value, const CUTF16String &expected)
{
    require(value.fLength == expected.size(), "exact UTF-16 length");
    if (value.fString) {
        PA_Unichar *buffer = value.fString;
        require(strings.count(buffer), "string allocation remains alive");
        require(value.fString[value.fLength] == 0, "UTF-16 terminator");
        require(CUTF16String(value.fString, value.fLength) == expected, "exact UTF-16 content");
    } else {
        require(expected.empty(), "null only represents empty");
    }
}

static SyntheticPicture *makePicture()
{
    SyntheticPicture *p = new SyntheticPicture{1};
    pictures.insert(p);
    return p;
}

static void disposePicture(PA_Picture value)
{
    if (!value) return;
    SyntheticPicture *p = static_cast<SyntheticPicture *>(value);
    require(pictures.count(p), "picture owner remains alive");
    require(p->refs > 0, "positive picture references");
    if (--p->refs == 0) {
        pictures.erase(p);
        delete p;
    }
}

static void clearVariable(PA_Variable *value)
{
    if (value->fFiller) {
        require(false, "metadata cleanup is outside this shim's contract");
    }
    switch (value->fType) {
        case eVK_Unistring:
            disposeString(value->uValue.fString);
            break;
        case eVK_Picture:
            disposePicture(value->uValue.fPicture);
            break;
        case eVK_ArrayUnicode: {
            PA_Handle h = value->uValue.fArray.fData;
            require(handles.count(h), "array handle remains alive");
            PA_Unistring *data = reinterpret_cast<PA_Unistring *>(*h);
            for (int i = 0; i <= value->uValue.fArray.fNbElements; ++i)
                disposeString(data[i]);
            PA_DisposeHandle(h);
            break;
        }
        case eVK_Undefined:
        case eVK_Longint:
            break;
        default:
            require(false, "unexpected variable cleanup");
    }
    value->fType = eVK_Undefined;
    value->fFiller = 0;
}

static void command(EngineBlock *eb)
{
    PA_Variable **args = static_cast<PA_Variable **>(eb->fPtr1);
    PA_Variable *result = static_cast<PA_Variable *>(eb->fPtr2);
    *result = PA_CreateVariable(eVK_Undefined);
    eb->fError = 0;
    switch (eb->fParam1) {
        case 678:
            require(eb->fParam2 == 2, "READ PICTURE FILE arity");
            checkString(args[0]->uValue.fString, expectedText);
            clearVariable(args[1]);
            PA_SetPictureVariable(args[1], makePicture());
            break;
        case 1002:
            require(eb->fParam2 == 2, "CONVERT PICTURE arity");
            checkString(args[1]->uValue.fString, expectedText);
            if (replacePicture) {
                clearVariable(args[0]);
                PA_SetPictureVariable(args[0], makePicture());
            }
            break;
        case 988:
            require(PA_GetLongintVariable(*args[1]) == 101, "grayscale transform");
            if (replacePicture) {
                clearVariable(args[0]);
                PA_SetPictureVariable(args[0], makePicture());
            }
            break;
        case 457:
            require(pictures.count(static_cast<SyntheticPicture *>(args[0]->uValue.fPicture)),
                    "borrowed picture input remains alive");
            PA_SetLongintVariable(args[1], 23);
            PA_SetLongintVariable(args[2], 17);
            break;
        case 679:
            require(pictures.count(static_cast<SyntheticPicture *>(args[0]->uValue.fPicture)),
                    "thumbnail borrowed input remains alive");
            require(PA_GetLongintVariable(*args[2]) == 23 &&
                    PA_GetLongintVariable(*args[3]) == 17, "thumbnail dimensions");
            clearVariable(args[1]);
            PA_SetPictureVariable(args[1], makePicture());
            break;
        default:
            require(false, "unhandled synthetic command");
    }
}

static void engine(short selector, EngineBlock *eb)
{
    switch (selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            break;
        case EX_SET_UNISTRING: {
            PA_Unistring replacement = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            disposeString(eb->fUniString1);
            eb->fUniString1 = replacement;
            break;
        }
        case EX_DISPOSE_UNISTRING:
            disposeString(eb->fUniString1);
            break;
        case EX_CREATE_PICTURE:
            eb->fPicture = makePicture();
            break;
        case EX_DISPOSE_PICTURE:
            disposePicture(eb->fPicture);
            break;
        case EX_DUPLICATE_PICTURE: {
            SyntheticPicture *p = static_cast<SyntheticPicture *>(eb->fPicture);
            require(pictures.count(p), "duplicate source alive");
            if (eb->fParam1 == 0) ++p->refs;
            else eb->fPicture = makePicture();
            break;
        }
        case EX_GET_PICTURE_DATA:
            // No representations. Returned text ownership is deliberately not
            // modeled: the SDK does not establish that contract.
            eb->fError = eER_IncompatibleTypes;
            eb->fUniString1 = {};
            break;
        case EX_CLEAR_VARIABLE:
            clearVariable(static_cast<PA_Variable *>(eb->fPtr1));
            break;
        case EX_EXECUTE_COMMAND_BY_ID:
            command(eb);
            break;
        case EX_CONVERT_CHARSET_TO_CHARSET: {
            require(eb->fParam2 == eVTC_UTF_8 && eb->fParam4 == eVTC_UTF_16,
                    "tested charset conversion direction");
            CFStringRef s = CFStringCreateWithBytes(kCFAllocatorDefault,
                static_cast<UInt8 *>(eb->fPtr1), eb->fParam1, kCFStringEncodingUTF8, false);
            require(s != NULL, "valid UTF-8 conversion fixture");
            size_t bytes = CFStringGetLength(s) * sizeof(PA_Unichar);
            require(bytes <= static_cast<size_t>(eb->fParam3), "conversion capacity is bytes");
            CFStringGetCharacters(s, CFRangeMake(0, CFStringGetLength(s)),
                                  static_cast<UniChar *>(eb->fPtr2));
            // SDK reports payload bytes, not code units or a terminator.
            eb->fParam3 = bytes;
            eb->fError = 0;
            CFRelease(s);
            break;
        }
        case EX_HANDLE_MANAGER: {
            eb->fError = 0;
            PA_Handle h = eb->fHandle;
            switch (eb->fParam1) {
                case 1:
                    h = new char *;
                    *h = static_cast<char *>(std::calloc(1, eb->fParam2 ? eb->fParam2 : 1));
                    handles[h] = eb->fParam2;
                    eb->fHandle = h;
                    break;
                case 2:
                    require(handles.erase(h) == 1, "dispose live handle");
                    std::free(*h);
                    delete h;
                    break;
                case 3:
                    require(handles.count(h), "resize live handle");
                    *h = static_cast<char *>(std::realloc(*h, eb->fParam2 ? eb->fParam2 : 1));
                    require(*h != NULL, "synthetic handle allocation");
                    handles[h] = eb->fParam2;
                    break;
                case 4:
                    require(handles.count(h), "size live handle");
                    eb->fParam2 = handles[h];
                    break;
                case 5:
                    require(handles.count(h), "lock live handle");
                    eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h);
                    break;
                case 6:
                    require(handles.count(h), "unlock live handle");
                    break;
                default:
                    require(false, "unhandled handle operation");
            }
            break;
        }
        default:
            std::fprintf(stderr, "unexpected engine selector: %d\n", selector);
            std::exit(1);
    }
}

void PluginMain(PA_long32, PA_PluginParameters) {}

static CUTF16String utf16(const char *text)
{
    CFStringRef s = CFStringCreateWithCString(NULL, text, kCFStringEncodingUTF8);
    require(s != NULL, "valid fixture");
    CUTF16String result(CFStringGetLength(s), 0);
    if (!result.empty())
        CFStringGetCharacters(s, CFRangeMake(0, result.size()), &result[0]);
    CFRelease(s);
    return result;
}

static void balanced()
{
    require(strings.empty(), "all string allocations released");
    require(handles.empty(), "all handles released");
    require(pictures.empty(), "all picture references released");
}

static void arrayContracts()
{
    PA_Variable array = PA_CreateVariable(eVK_ArrayUnicode);
    PA_ResizeArray(&array, 3);
    const char *fixtures[] = {"", "ASCII", "\xE6\x97\xA5", "\xF0\x9F\x98\x80"};
    for (int i = 0; i < 4; ++i) {
        CUTF16String text = utf16(fixtures[i]);
        PA_Unistring owned = PA_CreateUnistring(const_cast<PA_Unichar *>(text.c_str()));
        PA_SetStringInArray(array, i, &owned);
        require(PA_GetStringInArray(array, i).fString == owned.fString,
                "accepted array assignment transfers descriptor");
        checkString(PA_GetStringInArray(array, i), text);
    }
    ARRAY_TEXT copy;
    BytePtr params[] = {reinterpret_cast<BytePtr>(&array)};
    copy.fromParamAtIndex(params, 1);
    PA_ClearVariable(&array);
    array = PA_CreateVariable(eVK_Undefined);
    copy.toParamAtIndex(params, 1);
    for (int i = 0; i < 4; ++i)
        checkString(PA_GetStringInArray(array, i), utf16(fixtures[i]));
    copy.toParamAtIndex(params, 1); // replacement must dispose old elements
    PA_Variable second = PA_CreateVariable(eVK_Undefined);
    BytePtr output[] = {reinterpret_cast<BytePtr>(&second)};
    copy.toParamAtIndex(output, 1);
    for (int i = 1; i < 4; ++i)
        require(PA_GetStringInArray(array, i).fString !=
                PA_GetStringInArray(second, i).fString, "independent transferred owners");
    PA_ClearVariable(&array);
    for (int i = 0; i < 4; ++i)
        checkString(PA_GetStringInArray(second, i), utf16(fixtures[i]));
    PA_ResizeArray(&second, 0);
    PA_ClearVariable(&second);
    CUTF16String text = utf16("retained on rejection");
    PA_Unistring owned = PA_CreateUnistring(const_cast<PA_Unichar *>(text.c_str()));
    PA_Variable wrong = PA_CreateVariable(eVK_Longint);
    PA_SetStringInArray(wrong, 0, &owned);
    array = PA_CreateVariable(eVK_ArrayUnicode);
    PA_SetStringInArray(array, -1, &owned);
    PA_SetStringInArray(array, 1, &owned);
    PA_Variable noData = {};
    noData.fType = eVK_ArrayUnicode;
    PA_SetStringInArray(noData, 0, &owned);
    PA_SetStringInArray(array, 0, NULL);
    checkString(owned, text);
    PA_DisposeUnistring(&owned);
    PA_ClearVariable(&array);
    balanced();
}

static void scalarContracts()
{
    for (const char *text : {"", "ASCII", "\xE6\x97\xA5", "\xF0\x9F\x98\x80"}) {
        CUTF16String expected = utf16(text);
        PA_Unistring input = PA_CreateUnistring(const_cast<PA_Unichar *>(expected.c_str()));
        C_TEXT copy;
        BytePtr params[] = {reinterpret_cast<BytePtr>(&input)};
        copy.fromParamAtIndex(params, 1);
        PA_DisposeUnistring(&input);
        copy.toParamAtIndex(params, 1);
        checkString(input, expected);
        PA_Unistring returned = {};
        PA_Unistring *result = &returned;
        copy.setReturn(reinterpret_cast<sLONG_PTR *>(&result));
        PA_DisposeUnistring(&input);
        checkString(returned, expected);
        PA_DisposeUnistring(&returned);
    }
    balanced();
}

int main(int argc, char **argv)
{
    require(argc == 2, "named test required");
    gCall4D = engine;
    const std::string test = argv[1];
    @autoreleasepool {
        for (bool empty : {false, true}) {
            nullEmpty = empty;
            for (bool replace : {false, true}) {
                replacePicture = replace;
                if (test == "arrays") { arrayContracts(); continue; }
                if (test == "scalars") { scalarContracts(); continue; }
                {
                    CPicture picture;
                    if (test == "path") {
                        for (const char *path : {"", "synthetic.png",
                             "\xE6\x97\xA5.png", "\xF0\x9F\x98\x80.png"}) {
                            expectedText = utf16(path);
                            CUTF8String p(reinterpret_cast<const uint8_t *>(path));
                            picture.fromFileAtPath(&p);
                            require(pictures.count(static_cast<SyntheticPicture *>(picture.getPicture())),
                                    "loaded picture survives owning argument cleanup");
                        }
                    } else if (test == "bytes") {
                        const uint8_t bytes[] = {1, 2, 3};
                        for (int i = 0; i < 8; ++i) picture.setBytes(bytes, sizeof(bytes));
                    } else if (test == "copy") {
                        for (const char *type : {".png", "\xE6\x97\xA5",
                                                "\xF0\x9F\x98\x80", ""}) {
                            expectedText = utf16(type);
                            PA_Picture owned = picture.createCopy(type);
                            require(pictures.count(static_cast<SyntheticPicture *>(owned)),
                                    "copy owning handoff survives argument cleanup");
                            PA_DisposePicture(owned);
                        }
                    } else if (test == "gray") {
                        PA_Picture owned = picture.createGrayScale();
                        require(pictures.count(static_cast<SyntheticPicture *>(owned)), "gray handoff alive");
                        PA_DisposePicture(owned);
                    } else if (test == "size") {
                        unsigned width = 0, height = 0;
                        picture.getSize(&width, &height);
                        require(width == 23 && height == 17, "exact picture size");
                    } else if (test == "thumbnail") {
                        PA_Picture owned = picture.createThumbnail(23, 17);
                        require(pictures.count(static_cast<SyntheticPicture *>(owned)), "thumbnail handoff alive");
                        PA_DisposePicture(owned);
                    } else {
                        require(false, "unknown test");
                    }
                }
                balanced();
            }
        }
    }
    std::printf("PASS %s (allocated/null empties; unchanged/replaced outputs; balanced owners)\n",
                test.c_str());
}
