#pragma once

#include <cstdint>
#include <string>
#include <mach-o/dyld.h>
#include <mach-o/loader.h> // veya mach-o/loader.h

class MemoryInfo
{
public:
    uint32_t index;
    const mach_header *header;
    const char *name;
    intptr_t address;
};

// Credit KittyMemory
inline MemoryInfo getBaseAddress(const std::string &fileName)
{
    MemoryInfo _info = {0, nullptr, nullptr, 0};

    const uint32_t imageCount = _dyld_image_count();

    for (uint32_t i = 0; i < imageCount; i++)
    {
        const char *name = _dyld_get_image_name(i);
        if (!name)
            continue;

        std::string fullpath(name);

        if (fullpath.length() < fileName.length() || fullpath.compare(fullpath.length() - fileName.length(), fileName.length(), fileName) != 0)
            continue;

        _info.index = i;
        _info.header = _dyld_get_image_header(i);
        _info.name = _dyld_get_image_name(i);
        _info.address = _dyld_get_image_vmaddr_slide(i);

        break;
    }
    return _info;
}
