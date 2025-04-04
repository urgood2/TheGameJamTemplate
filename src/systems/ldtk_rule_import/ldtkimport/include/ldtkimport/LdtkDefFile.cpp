#include "LdtkDefFile.hpp"

#include <climits>
#include <cstring>
#include <cmath>
#include <fstream>
#include <sstream>
#include <iostream>
#include <iomanip>

#define __STDC_WANT_LIB_EXT1__ 1
#include <stdio.h>

#include "yyjson.hpp"

#include "MiscUtility.h"
#include "AssertUtility.h"


namespace ldtkimport
{

bool yyjson_obj_get_bool(yyjson_val *obj, const char *key)
{
   auto got_obj = yyjson_obj_get(obj, key);
   return yyjson_get_bool(got_obj);
}

int yyjson_obj_get_int(yyjson_val *obj, const char *key)
{
   auto got_obj = yyjson_obj_get(obj, key);
   return yyjson_get_int(got_obj);
}

float yyjson_obj_get_float(yyjson_val *obj, const char *key)
{
   auto got_obj = yyjson_obj_get(obj, key);
   if (yyjson_is_int(got_obj))
   {
      return static_cast<float>(yyjson_get_int(got_obj));
   }
   return static_cast<float>(yyjson_get_real(got_obj));
}

const char *yyjson_obj_get_str(yyjson_val *obj, const char *key)
{
   auto got_obj = yyjson_obj_get(obj, key);
   return yyjson_get_str(got_obj);
}


void LdtkDefFile::setLayerInitialSeed(int layerDefUid, int newInitialSeed)
{
   for (size_t layerIdx = 0, layerLen = m_layers.size(); layerIdx < layerLen; ++layerIdx)
   {
      if (m_layers[layerIdx].uid == layerDefUid)
      {
         m_layers[layerIdx].initialRandomSeed = newInitialSeed;
         return;
      }
   }
}

TileSet *LdtkDefFile::getTileset(int tilesetDefUid)
{
   for (auto i = m_tilesets.data(), end = m_tilesets.data() + m_tilesets.size(); i != end; ++i)
   {
      if (i->uid == tilesetDefUid)
      {
         return i;
      }
   }

   return nullptr;
}

const TileSet *LdtkDefFile::getTileset(int tilesetDefUid) const
{
   for (auto i = m_tilesets.data(), end = m_tilesets.data() + m_tilesets.size(); i != end; ++i)
   {
      if (i->uid == tilesetDefUid)
      {
         return i;
      }
   }

   return nullptr;
}

Layer *LdtkDefFile::getLayerByUid(int layerDefUid)
{
   for (auto i = m_layers.data(), end = m_layers.data() + m_layers.size(); i != end; ++i)
   {
      if (i->uid == layerDefUid)
      {
         return i;
      }
   }

   return nullptr;
}

const Layer *LdtkDefFile::getLayerByUid(int layerDefUid) const
{
   for (auto i = m_layers.cbegin(), end = m_layers.cend(); i != end; ++i)
   {
      if (i->uid == layerDefUid)
      {
         return &*i;
      }
   }

   return nullptr;
}


const RuleGroup *LdtkDefFile::getRuleGroupOfRule(int ruleUid) const
{
   for (auto i = m_layers.cbegin(), end = m_layers.cend(); i != end; ++i)
   {
      for (auto r = i->ruleGroups.cbegin(), rEnd = i->ruleGroups.cend(); r != rEnd; ++r)
      {
         for (auto rule = r->rules.cbegin(), ruleEnd = r->rules.cend(); rule != ruleEnd; ++rule)
         {
            if (rule->uid == ruleUid)
            {
               return &*r;
            }
         }
      }
   }

   return nullptr;
}

#define USE_IFSTREAM

bool LdtkDefFile::loadFromFile(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   RulesLog &rulesLog,
#endif
   const char *ldtkFile, bool loadDeactivatedContent)
{
#if defined(USE_FOPEN)

   FILE *f = fopen(ldtkFile, "r");
   if (f == nullptr)
   {
      //lua_pushboolean(L, 0);
      //lua_pushstring(L, "error: file could not be opened: \"%s\"", got_string_param);
      return false;
   }

   fseek(f, 0, SEEK_END);
   off_t fsize = ftell(f);
   fseek(f, 0, SEEK_SET);
   7
      std::unique_ptr<char[]> buffer(new char[fsize + 1]);
   off_t bytesRead = fread(buffer.get(), fsize, 1, f);
   fclose(f);

   if (fsize != bytesRead)
   {
      return false;
   }

   auto jsonText = buffer.get();
   size_t jsonTextLen = fsize + 1;

#elif defined(USE_IFSTREAM)

   std::ifstream file(ldtkFile);

   if (!file.good())
   {
      return false;
   }

   std::stringstream bufferstream;
   bufferstream << file.rdbuf();

   file.close();

   auto buffer_string = bufferstream.str();

   auto jsonText = buffer_string.c_str();
   size_t jsonTextLen = buffer_string.length();
#endif

   loadFromText(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
      rulesLog,
#endif
      jsonText, jsonTextLen, loadDeactivatedContent, ldtkFile);

   return true;
}

const char *LAYER_TYPE_AUTO_LAYER = "AutoLayer";
const char *LAYER_TYPE_INT_GRID = "IntGrid";

const char *RULE_CHECKER_MODE_NONE = "None";
const char *RULE_CHECKER_MODE_HORIZONTAL = "Horizontal";
const char *RULE_CHECKER_MODE_VERTICAL = "Vertical";

const char *TILE_MODE_SINGLE = "Single";
const char *TILE_MODE_STAMP = "Stamp";

void LdtkDefFile::loadFromText(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   RulesLog &rulesLog,
#endif
   const char *ldtkText, size_t textLength, bool loadDeactivatedContent, const char *filename)
{
   auto ldtk_json = yyjson_read(ldtkText, textLength, 0);
   if (ldtk_json == nullptr)
   {
      return;
   }

   auto root = yyjson_doc_get_root(ldtk_json);
   if (root == nullptr)
   {
      // empty json file
      yyjson_doc_free(ldtk_json);
      return;
   }

   // ---------------------------------------------------------------------------------

   //auto header = yyjson_obj_get(root, "__header__");
   //auto appAuthor = yyjson_obj_get(header, "appAuthor");

   //auto gotAppAuthor = yyjson_get_str(appAuthor);
   //std::string copiedAppAuthor(gotAppAuthor);

   //std::cout << "Author: " << copiedAppAuthor << std::endl;

   // ---------------------------------------------------------------------------------

   auto uniqueProjectId = yyjson_obj_get(root, "iid");
   if (uniqueProjectId == nullptr)
   {
      // missing "iid"
      yyjson_doc_free(ldtk_json);
      return;
   }

   m_filename = filename;
   m_projectUniqueId = yyjson_get_str(uniqueProjectId);

   // ---------------------------------------------------------------------------------

   auto fileVersion = yyjson_obj_get(root, "jsonVersion");
   if (fileVersion == nullptr)
   {
      // missing "jsonVersion"
      yyjson_doc_free(ldtk_json);
      return;
   }

   m_fileVersion = yyjson_get_str(fileVersion);

   int major, minor, patch;
#if defined(__STDC_LIB_EXT1__) || defined(_MSC_VER)
   int successCount = sscanf_s(m_fileVersion.c_str(), "%d.%d.%d", &major, &minor, &patch);
#else
   int successCount = sscanf(m_fileVersion.c_str(), "%d.%d.%d", &major, &minor, &patch);
#endif
   if (successCount >= 3)
   {
      m_versionMajor = major;
      m_versionMinor = minor;
      m_versionPatch = patch;
   }
   else
   {
      m_versionMajor = -1;
      m_versionMinor = -1;
      m_versionPatch = -1;
   }

   // ---------------------------------------------------------------------------------

   auto defs = yyjson_obj_get(root, "defs");
   if (defs == nullptr)
   {
      // missing "defs"
      yyjson_doc_free(ldtk_json);
      return;
   }

   // inside defs is:
   // layers
   // entities
   // tilesets
   // enums
   // externalEnums
   // levelFields

   auto layers = yyjson_obj_get(defs, "layers");
   if (layers == nullptr)
   {
      // missing "layers"
      yyjson_doc_free(ldtk_json);
      return;
   }

   size_t layerIdx, layerLen;
   yyjson_val *layer = nullptr;
   m_layers.reserve(yyjson_arr_size(layers));
   yyjson_arr_foreach(layers, layerIdx, layerLen, layer)
   {
      const char *layerType = yyjson_obj_get_str(layer, "__type");

      if (std::strcmp(layerType, LAYER_TYPE_AUTO_LAYER) != 0 &&
          std::strcmp(layerType, LAYER_TYPE_INT_GRID) != 0)
      {
         // not a layer type that we support
         continue;
      }

      Layer newLayer;

      newLayer.name = yyjson_obj_get_str(layer, "identifier");
      newLayer.uid = yyjson_obj_get_int(layer, "uid");
      newLayer.cellPixelSize = yyjson_obj_get_int(layer, "gridSize");
      auto tilesetDefUid = yyjson_obj_get(layer, "tilesetDefUid");
      if (yyjson_is_null(tilesetDefUid))
      {
         newLayer.tilesetDefUid = 0;
      }
      else
      {
         newLayer.tilesetDefUid = yyjson_get_int(tilesetDefUid);
      }

      auto layerAutoSourceLayerDefUid = yyjson_obj_get(layer, "autoSourceLayerDefUid");
      newLayer.useAutoSourceLayerDefUid = !yyjson_is_null(layerAutoSourceLayerDefUid);
      newLayer.autoSourceLayerDefUid = yyjson_get_int(layerAutoSourceLayerDefUid);

      newLayer.initialRandomSeed = 0;

      auto intGridValues = yyjson_obj_get(layer, "intGridValues");
      size_t intGridValuesIdx, intGridValuesLen;
      yyjson_val *intGridValue = nullptr;
      intGridValuesLen = yyjson_arr_size(intGridValues);
      newLayer.intGridValues.reserve(intGridValuesLen);
      yyjson_arr_foreach(intGridValues, intGridValuesIdx, intGridValuesLen, intGridValue)
      {
         IntGridValue newIntGridValue;
         newIntGridValue.id = yyjson_obj_get_int(intGridValue, "value");
         newIntGridValue.name = yyjson_obj_get_str(intGridValue, "identifier");
         newLayer.intGridValues.push_back(newIntGridValue);
      }

      auto autoRuleGroups = yyjson_obj_get(layer, "autoRuleGroups");
      size_t autoRuleGroupIdx, autoRuleGroupLen;
      yyjson_val *autoRuleGroup = nullptr;
      if (loadDeactivatedContent)
      {
         autoRuleGroupLen = yyjson_arr_size(autoRuleGroups);
         newLayer.ruleGroups.reserve(autoRuleGroupLen);
      }
      yyjson_arr_foreach(autoRuleGroups, autoRuleGroupIdx, autoRuleGroupLen, autoRuleGroup)
      {
         bool ruleGroupActive = yyjson_obj_get_bool(autoRuleGroup, "active");
         if (!loadDeactivatedContent && !ruleGroupActive)
         {
            //std::cout << "   Skipping since deactivated" << std::endl;
            continue;
         }

         RuleGroup newRuleGroup;

         newRuleGroup.active = ruleGroupActive;
         newRuleGroup.name = yyjson_obj_get_str(autoRuleGroup, "name");
         //std::cout << "In layer " << newLayer.name << ", got autoRuleGroup: " << newRuleGroup.name << std::endl;

         auto autoRules = yyjson_obj_get(autoRuleGroup, "rules");
         size_t autoRuleIdx, autoRuleLen;
         yyjson_val *autoRule = nullptr;
         if (loadDeactivatedContent)
         {
            autoRuleLen = yyjson_arr_size(autoRules);
            newRuleGroup.rules.reserve(autoRuleLen);
         }
         yyjson_arr_foreach(autoRules, autoRuleIdx, autoRuleLen, autoRule)
         {
            bool ruleActive = yyjson_obj_get_bool(autoRule, "active");
            if (!loadDeactivatedContent && !ruleActive)
            {
               continue;
            }

            Rule newRule;
            newRule.active = ruleActive;

            newRule.uid = yyjson_obj_get_int(autoRule, "uid");
            newRule.patternSize = yyjson_obj_get_int(autoRule, "size");


            // REVIEW: old code that does not work with newest LDTK version

            // auto tileIds = yyjson_obj_get(autoRule, "tileRectsIds");
            // newRule.tileIds.reserve(yyjson_arr_size(tileIds));
            // size_t tileIdIdx, tileIdLen;
            // yyjson_val *tileId = nullptr;
            // yyjson_arr_foreach(tileIds, tileIdIdx, tileIdLen, tileId)
            // {
            //    newRule.tileIds.push_back(yyjson_get_int(tileId));
            // }

            //FIXME: some of the tile rules seem broken

            // try new code
            auto tileRectsIds = yyjson_obj_get(autoRule, "tileRectsIds");
            // Check if tileRectsIds is indeed an array
            size_t outerArraySize = yyjson_arr_size(tileRectsIds);
            // Reserve space in tileIds vector for efficiency
            newRule.tileIds.reserve(outerArraySize);
            
            for (size_t i = 0; i < outerArraySize; ++i) {
               yyjson_val *innerArray = yyjson_arr_get(tileRectsIds, i);
               
               // Assuming each innerArray should contain exactly one element (the tile id)
               if (yyjson_arr_size(innerArray) == 1) {
                     yyjson_val *tileIdValue = yyjson_arr_get(innerArray, 0);
                     // Push the tile id into the vector
                     newRule.tileIds.push_back(yyjson_get_int(tileIdValue));
               }
            }

            if (isVersionAtLeast(1, 3, 1))
            {
               newRule.opacity = static_cast<uint8_t>(yyjson_obj_get_float(autoRule, "alpha") * 100);
            }

            newRule.chance = yyjson_obj_get_float(autoRule, "chance");
            newRule.breakOnMatch = yyjson_obj_get_bool(autoRule, "breakOnMatch");

            auto pattern = yyjson_obj_get(autoRule, "pattern");
            newRule.pattern.reserve(yyjson_arr_size(pattern));
            size_t patternIdx, patternLen;
            yyjson_val *patternIntGridValue = nullptr;
            yyjson_arr_foreach(pattern, patternIdx, patternLen, patternIntGridValue)
            {
               newRule.pattern.push_back(yyjson_get_int(patternIntGridValue));
            }

            newRule.flipX = yyjson_obj_get_bool(autoRule, "flipX");
            newRule.flipY = yyjson_obj_get_bool(autoRule, "flipY");

            newRule.xModulo = yyjson_obj_get_int(autoRule, "xModulo");
            newRule.yModulo = yyjson_obj_get_int(autoRule, "yModulo");

            // modulo values are used as divisors, so they shouldn't be 0
            // there's also no point in them being negative
            if (newRule.xModulo < 1)
            {
               newRule.xModulo = 1;
            }
            if (newRule.yModulo < 1)
            {
               newRule.yModulo = 1;
            }

            newRule.xModuloOffset = yyjson_obj_get_int(autoRule, "xOffset");
            newRule.yModuloOffset = yyjson_obj_get_int(autoRule, "yOffset");

            if (isVersionAtLeast(1, 3, 0))
            {
               newRule.posXOffset = yyjson_obj_get_int(autoRule, "tileXOffset");
               newRule.posYOffset = yyjson_obj_get_int(autoRule, "tileYOffset");
               newRule.randomPosXOffsetMin = yyjson_obj_get_int(autoRule, "tileRandomXMin");
               newRule.randomPosXOffsetMax = yyjson_obj_get_int(autoRule, "tileRandomXMax");
               newRule.randomPosYOffsetMin = yyjson_obj_get_int(autoRule, "tileRandomYMin");
               newRule.randomPosYOffsetMax = yyjson_obj_get_int(autoRule, "tileRandomYMax");
            }

            auto checkerString = yyjson_obj_get_str(autoRule, "checker");
            if (std::strcmp(checkerString, RULE_CHECKER_MODE_NONE) == 0)
            {
               newRule.checker = Rule::CheckerMode::None;
            }
            else if (std::strcmp(checkerString, RULE_CHECKER_MODE_HORIZONTAL) == 0)
            {
               newRule.checker = Rule::CheckerMode::Horizontal;
            }
            else if (std::strcmp(checkerString, RULE_CHECKER_MODE_VERTICAL) == 0)
            {
               newRule.checker = Rule::CheckerMode::Vertical;
            }
            else
            {
               // default to None if not recognized
               newRule.checker = Rule::CheckerMode::None;
            }

            auto tileMode = yyjson_obj_get_str(autoRule, "tileMode");
            if (std::strcmp(tileMode, TILE_MODE_SINGLE) == 0)
            {
               newRule.tileMode = Rule::TileMode::Single;
            }
            else if (std::strcmp(tileMode, TILE_MODE_STAMP) == 0)
            {
               newRule.tileMode = Rule::TileMode::Stamp;
            }
            else
            {
               // default to Single if not recognized
               newRule.tileMode = Rule::TileMode::Single;
            }

            newRule.stampPivotX = yyjson_obj_get_float(autoRule, "pivotX");
            newRule.stampPivotY = yyjson_obj_get_float(autoRule, "pivotY");

            auto outOfBoundsValue = yyjson_obj_get(autoRule, "outOfBoundsValue");
            if (yyjson_is_null(outOfBoundsValue))
            {
               newRule.verticalOutOfBoundsValue = -1;
               newRule.horizontalOutOfBoundsValue = -1;
            }
            else
            {
               newRule.verticalOutOfBoundsValue = yyjson_get_int(outOfBoundsValue);
               newRule.horizontalOutOfBoundsValue = newRule.verticalOutOfBoundsValue;
            }

            newRuleGroup.rules.push_back(newRule);
         }

         newLayer.ruleGroups.push_back(newRuleGroup);
      }

      m_layers.push_back(newLayer);
   }

   // ---------------------------------------------------------------------------------

   auto tilesets = yyjson_obj_get(defs, "tilesets");
   m_tilesets.reserve(yyjson_arr_size(tilesets));
   size_t tilesetIdx, tilesetLen;
   yyjson_val *tileset = nullptr;
   yyjson_arr_foreach(tilesets, tilesetIdx, tilesetLen, tileset)
   {
      TileSet newTileset;

      newTileset.tileCountWidth = yyjson_obj_get_int(tileset, "__cWid");
      newTileset.tileCountHeight = yyjson_obj_get_int(tileset, "__cHei");
      newTileset.name = yyjson_obj_get_str(tileset, "identifier");
      newTileset.uid = yyjson_obj_get_int(tileset, "uid");
      newTileset.imagePath = yyjson_obj_get_str(tileset, "relPath");
      newTileset.imageWidth = yyjson_obj_get_int(tileset, "pxWid");
      newTileset.imageHeight = yyjson_obj_get_int(tileset, "pxHei");
      newTileset.tileSize = yyjson_obj_get_int(tileset, "tileGridSize");
      newTileset.spacing = yyjson_obj_get_int(tileset, "spacing");
      newTileset.margin = yyjson_obj_get_int(tileset, "padding");

      m_tilesets.push_back(newTileset);
   }

   // ---------------------------------------------------------------------------------

   auto levels = yyjson_obj_get(root, "levels");

   size_t levelIdx, levelLen;
   yyjson_val *level = nullptr;
   yyjson_val *gotBgColor = nullptr;
   yyjson_arr_foreach(levels, levelIdx, levelLen, level)
   {
      if (gotBgColor == nullptr)
      {
         gotBgColor = yyjson_obj_get(level, "__bgColor");
      }

      auto layerInstances = yyjson_obj_get(level, "layerInstances");
      if (yyjson_is_null(layerInstances))
      {
         // level was probably saved in a separate file
         continue;
      }

      size_t layerInstanceIdx, layerInstanceLen;
      yyjson_val *layerInstance = nullptr;
      yyjson_arr_foreach(layerInstances, layerInstanceIdx, layerInstanceLen, layerInstance)
      {
         auto layerDefUid = yyjson_obj_get_int(layerInstance, "layerDefUid");
         setLayerInitialSeed(layerDefUid, yyjson_obj_get_int(layerInstance, "seed"));
      }
   }

   if (gotBgColor != nullptr)
   {
      m_bgColor = yyjson_get_str(gotBgColor);
   }
   else
   {
      //std::cout << "Did not get any level BG color" << std::endl;
      m_bgColor = yyjson_obj_get_str(root, "defaultLevelBgColor");
   }

   // ---------------------------------------------------------------------------------

   // any value we get from yyjson will become null after this call,
   // so they should be copied to new variables before calling this
   yyjson_doc_free(ldtk_json);

   preProcess(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
      rulesLog,
#endif
      loadDeactivatedContent);
}

void LdtkDefFile::preProcess(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   RulesLog &rulesLog,
#endif
   bool preProcessDeactivatedContent)
{
   int r, g, b;
#if defined(__STDC_LIB_EXT1__) || defined(_MSC_VER)
   int successCount = sscanf_s(m_bgColor.c_str(), "#%02x%02x%02x", &r, &g, &b);
#else
   int successCount = sscanf(m_bgColor.c_str(), "#%02x%02x%02x", &r, &g, &b);
#endif
   if (successCount == 3)
   {
      m_bgColor8.r = static_cast<uint8_t>(r);
      m_bgColor8.g = static_cast<uint8_t>(g);
      m_bgColor8.b = static_cast<uint8_t>(b);

      m_bgColorf.r = static_cast<float>(r) / UINT8_MAX;
      m_bgColorf.g = static_cast<float>(g) / UINT8_MAX;
      m_bgColorf.b = static_cast<float>(b) / UINT8_MAX;
   }
   else
   {
      m_bgColor8.r = UINT8_MAX;
      m_bgColor8.g = UINT8_MAX;
      m_bgColor8.b = UINT8_MAX;

      m_bgColorf.r = 1;
      m_bgColorf.g = 1;
      m_bgColorf.b = 1;
   }

   for (auto layer = m_layers.begin(), layerEnd = m_layers.end(); layer != layerEnd; ++layer)
   {
      TileSet *tileset = getTileset(layer->tilesetDefUid);
      if (tileset == nullptr)
      {
         // can't find tileset for this layer
         continue;
      }

      // be extra sure
      ASSERT(tileset != nullptr, "result arg of getTileset should not be null if return value is true");

      for (auto ruleGroup = layer->ruleGroups.begin(), ruleGroupEnd = layer->ruleGroups.end(); ruleGroup != ruleGroupEnd; ++ruleGroup)
      {
         if (!ruleGroup->active && !preProcessDeactivatedContent)
         {
            continue;
         }

         for (auto rule = ruleGroup->rules.begin(), ruleEnd = ruleGroup->rules.end(); rule != ruleEnd; ++rule)
         {
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
            if (rulesLog.rule.count(rule->uid) == 0)
            {
               rulesLog.rule.insert(std::make_pair(rule->uid, RuleLog()));
            }
            rulesLog.rule[rule->uid].stampDebugInfo = "";
#endif

            if (!rule->active && !preProcessDeactivatedContent)
            {
               continue;
            }

            if (rule->tileMode != Rule::TileMode::Stamp)
            {
               // non-stamp rule, then we don't need to process the offsets
               continue;
            }

            if (rule->tileIds.size() == 0)
            {
               // no tiles for this rule, no point in processing
               continue;
            }

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
            std::stringstream stampDebugLog;
#endif

            // get stamp bounds (within the tilesheet's space)
            int16_t top = SHRT_MAX;
            int16_t left = SHRT_MAX;
            int16_t right = SHRT_MIN;
            int16_t bottom = SHRT_MIN;
            for (auto tileId = rule->tileIds.begin(), tileIdEnd = rule->tileIds.end(); tileId != tileIdEnd; ++tileId)
            {
               int16_t x, y;
               tileset->getCoordinates(*tileId, x, y);

               top = std::min(top, y);
               left = std::min(left, x);
               bottom = std::max(bottom, y);
               right = std::max(right, x);
            }

            ASSERT(top >= 0, "top should not be negative. top: " << top);
            ASSERT(left >= 0, "left should not be negative. left: " << left);
            ASSERT(bottom >= 0, "bottom should not be negative. bottom: " << bottom);
            ASSERT(right >= 0, "right should not be negative. right: " << right);

            ASSERT(top < tileset->tileCountHeight, "top should not be beyond height. top: " << top << " height: " << tileset->tileCountHeight);
            ASSERT(left < tileset->tileCountWidth, "left should not be beyond width. left: " << left << " width: " << tileset->tileCountWidth);
            ASSERT(bottom < tileset->tileCountHeight, "top should not be beyond height. bottom: " << bottom << " height: " << tileset->tileCountHeight);
            ASSERT(right < tileset->tileCountWidth, "right should not be beyond width. right: " << right << " width: " << tileset->tileCountWidth);

            ASSERT(top <= bottom, "top should be <= bottom. top: " << top << " bottom: " << bottom);
            ASSERT(left <= right, "left should be <= right. left: " << left << " right: " << right);

            // Note: The width and height values are zero-based
            // (ex. width of 3 tiles will actually have a stampWidth value of 2),
            // which works out fine in the end for the stamp pivot calculations.
            int stampWidth = right - left, stampHeight = bottom - top;

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
            stampDebugLog << "stamp size: " << stampWidth + 1 << "x" << stampHeight + 1 << std::endl;
#endif

            // now each tile in the stamp needs to be given their local offset
            rule->stampTileOffsets.clear();
            rule->stampTileOffsets.reserve(rule->tileIds.size());

            for (auto tileId = rule->tileIds.begin(), tileIdEnd = rule->tileIds.end(); tileId != tileIdEnd; ++tileId)
            {
               int16_t x, y;
               tileset->getCoordinates(*tileId, x, y);

               uint8_t flags = TileFlags::NoFlags;

               // The x and y offsets are measured in "grid-space", not pixels.
               // So if a pivot is 0.5 and causes the tiles to be in-between the grid,
               // we can't store that in the offsets, which can only be whole numbers (ints).
               //
               // Instead, we mark that in the flag instead using TILE_OFFSET_LEFT and/or TILE_OFFSET_UP.
               //
               // For the code that will draw the tiles on-screen,
               // it will need to convert the offsets into pixels,
               // and those flags will be checked if a 0.5 adjustment is needed.
               //
               // This is only ever a problem when the pivot is 0.5 and the width/height is even-numbered.
               // For example:
               //
               // width of 3 tiles and pivot X of 0.5 won't be a problem, because it'll still be aligned to the grid:
               // (width of 3 tiles, whose stampWidth will come out as 2 since our values are zero-based) * (assigned pivot x of 0.5) = 2 * 0.5 = 1 (which means move entire stamp 1 tile to the left)
               //
               // but width of 2 tiles and pivot X of 0.5 won't be aligned to the grid:
               // (width of 2 tiles, whose stampWidth is actually 1) * (assigned pivot x of 0.5) = 1 * 0.5 = 0.5 (keep the entire stamp where it is but later on during rendering, move half tile size to the left)
               //
               auto horizontalAlignmentOffset = (rule->stampPivotX * stampWidth);
               auto verticalAlignmentOffset = (rule->stampPivotY * stampHeight);

               // ------------------------------

               float horizontalAlignmentWhole;
               float horizontalAlignmentFraction = std::modf(horizontalAlignmentOffset, &horizontalAlignmentWhole);

               if (horizontalAlignmentFraction > 0.0f)
               {
                  flags |= TileFlags::LeftOffset;
               }

               float verticalAlignmentOffsetWhole;
               float verticalAlignmentOffsetFraction = std::modf(verticalAlignmentOffset, &verticalAlignmentOffsetWhole);

               if (verticalAlignmentOffsetFraction > 0.0f)
               {
                  flags |= TileFlags::UpOffset;
               }

               // ------------------------------

               Rule::Offset o
               {
                  static_cast<int16_t>((x - left) - horizontalAlignmentWhole),
                  static_cast<int16_t>((y - top) - verticalAlignmentOffsetWhole),
                  flags
               };


#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
               stampDebugLog << "for tile id " << *tileId << ": offset: (" << o.x << ", " << o.y << ")";
               if (TileFlags::hasOffsetLeft(flags))
               {
                  stampDebugLog << " offsetX (h align: " << horizontalAlignmentWhole << " f: " << horizontalAlignmentFraction << ")";
               }
               if (TileFlags::hasOffsetUp(flags))
               {
                  stampDebugLog << " offsetY (v align: " << verticalAlignmentOffsetWhole << " f: " << verticalAlignmentOffsetFraction << ")";
               }
               stampDebugLog << std::endl;
#endif
               rule->stampTileOffsets.push_back(o);
            }

            ASSERT(rule->stampTileOffsets.size() == rule->tileIds.size(),
               "For rule " << rule->uid << ", stampTileOffsets size should match tileIds size at this point. stampTileOffsets.size(): " << rule->stampTileOffsets.size() << " tileIds.size(): " << rule->tileIds.size());

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
            rulesLog.rule[rule->uid].stampDebugInfo = stampDebugLog.str();
#endif
         } // for Rule
      } // for RuleGroup
   } // for Layer
}

bool LdtkDefFile::isValid() const
{
   for (auto layer = m_layers.cbegin(), layerEnd = m_layers.cend(); layer != layerEnd; ++layer)
   {
      for (auto ruleGroup = layer->ruleGroups.cbegin(), ruleGroupEnd = layer->ruleGroups.cend(); ruleGroup != ruleGroupEnd; ++ruleGroup)
      {
         if (!ruleGroup->active)
         {
            continue;
         }

         for (auto rule = ruleGroup->rules.cbegin(), ruleEnd = ruleGroup->rules.cend(); rule != ruleEnd; ++rule)
         {
            if (!rule->active)
            {
               continue;
            }

            if (rule->tileIds.size() == 0)
            {
               // no tiles for this rule, no point in processing
               continue;
            }

            if (!rule->isValid())
            {
               return false;
            }
         }
      }
   }

   // passed all checks
   return true;
}

void LdtkDefFile::runRules(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   RulesLog &rulesLog,
#endif
   Level &level, const uint8_t runSettings) const
{
   auto &intGrid = level.getIntGrid();

   if (intGrid.getWidth() == 0 || intGrid.getHeight() == 0)
   {
      // can't proceed, level size is wrong
      return;
   }

   // ensure level has same amount of TileGrids as there are layers
   level.setTileGridCount(m_layers.size());
   level.cleanUpTileGrids();

   ASSERT(level.getTileGridCount() == m_layers.size(), "TileGrid count of Level should match count of Layers after calling Level::setTileGridCount");

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   rulesLog.tileGrid.resize(m_layers.size(), RulesLog::RulesInGrid_t());
#endif


   for (size_t layerIdx = 0, end = m_layers.size(); layerIdx < end; ++layerIdx)
   {
      uint32_t randomSeed;
      if (RunSettings::hasRandomizeSeeds(runSettings))
      {
         randomSeed = rand();
      }
      else
      {
         randomSeed = m_layers[layerIdx].initialRandomSeed;
      }

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
      rulesLog.tileGrid[layerIdx].resize(level.getIntGrid().size(), RulesLog::RulesInCell_t());
#endif

      runRulesOnLayer(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
         rulesLog,
#endif
         level, layerIdx, randomSeed, runSettings);

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
      std::cout << "Finished running rules for layer idx " << layerIdx << std::endl;
#endif
   } // for Layer

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   std::cout << "Finished running all rules on all layers" << std::endl;
#endif
}

bool LdtkDefFile::ensureValidForRules(Level &level) const
{
   if (!isValid())
   {
      // something wrong with our own data
      return false;
   }

   auto &intGrid = level.getIntGrid();

   // we don't really have a limit on the level's size,
   // we only need it to be at least 1 in both width and height
   if (intGrid.getWidth() == 0 || intGrid.getHeight() == 0)
   {
      // can't proceed, level size is wrong
      return false;
   }

   // ensure level has same amount of TileGrids as there are layers
   level.setTileGridCount(m_layers.size());
   level.cleanUpTileGrids();

   ASSERT(level.getTileGridCount() == m_layers.size(), "TileGrid count of Level should match count of Layers after calling Level::setTileGridCount");
   return true;
}

void LdtkDefFile::runRulesOnLayer(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   RulesLog &rulesLog,
#endif
   Level &level, const size_t layerIdx, const uint32_t randomSeed, const uint8_t runSettings) const
{
   auto &intGrid = level.getIntGrid();
   auto &layer = m_layers[layerIdx];
   auto &tileGrid = level.getTileGridByIdx(layerIdx);

   tileGrid.setRandomSeed(randomSeed);
   tileGrid.setLayerUid(layer.uid);

   uint8_t rulePriority = 0;

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
   for (int cellY = 0; cellY < intGrid.getHeight(); ++cellY)
   {
      for (int cellX = 0; cellX < intGrid.getWidth(); ++cellX)
      {
         rulesLog.tileGrid[layerIdx][GridUtility::getIndex(cellX, cellY, intGrid.getWidth())].clear();
      }
   }
#endif

   for (auto ruleGroup = layer.ruleGroups.begin(), ruleGroupEnd = layer.ruleGroups.end(); ruleGroup != ruleGroupEnd; ++ruleGroup)
   {
      if (!ruleGroup->active)
      {
         continue;
      }

      for (auto rule = ruleGroup->rules.begin(), ruleEnd = ruleGroup->rules.end(); rule != ruleEnd; ++rule)
      {
         if (!rule->active)
         {
            continue;
         }

         if (rule->tileIds.size() == 0)
         {
            // no tiles for this rule, no point in processing
            continue;
         }

         if (rule->chance <= 0)
         {
            // no chance for this rule to occur, no point in processing
            continue;
         }

#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
         if (rulesLog.rule.count(rule->uid) == 0)
         {
            rulesLog.rule.insert(std::make_pair(rule->uid, RuleLog()));
         }
         std::cout << "Running Rule " << rule->uid << " of RuleGroup \"" << ruleGroup->name << "\" on layer idx " << layerIdx << " with random seed is " << randomSeed << std::endl;
#endif

         rule->applyRule(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
            rulesLog.rule[rule->uid], rulesLog.tileGrid[layerIdx],
#endif
            tileGrid, intGrid, randomSeed, layer.cellPixelSize, rulePriority, runSettings);

         ++rulePriority;
      } // for Rule
   } // for RuleGroup
}

void LdtkDefFile::debugPrintRule(std::ostream &outStream, int ruleUid) const
{
   for (auto layer = m_layers.cbegin(), layerEnd = m_layers.cend(); layer != layerEnd; ++layer)
   {
      for (auto ruleGroup = layer->ruleGroups.cbegin(), ruleGroupEnd = layer->ruleGroups.cend(); ruleGroup != ruleGroupEnd; ++ruleGroup)
      {
         for (auto rule = ruleGroup->rules.cbegin(), ruleEnd = ruleGroup->rules.cend(); rule != ruleEnd; ++rule)
         {
            if (rule->uid != ruleUid)
            {
               continue;
            }

            outStream << *rule << std::endl;

         } // for Rule
      } // for RuleGroup
   } // for Layer
}

} // namespace ldtkimport
