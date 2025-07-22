-- Test script to check spec information in MoP Classic
print("=== Testing Class and Spec Information ===")

-- Check if the APIs exist first
if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    print("C_CreatureInfo.GetClassInfo exists")
else
    print("C_CreatureInfo.GetClassInfo does NOT exist")
end

if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
    print("C_SpecializationInfo.GetNumSpecializationsForClassID exists")
else
    print("C_SpecializationInfo.GetNumSpecializationsForClassID does NOT exist")
end

if GetSpecializationInfoForClassID then
    print("GetSpecializationInfoForClassID exists")
else
    print("GetSpecializationInfoForClassID does NOT exist")
end

print("=== Attempting to run the spec detection code ===")

-- Try the original code
local success, error = pcall(function()
    for classID = 1, GetNumClasses() do
        local classInfo = C_CreatureInfo.GetClassInfo(classID)
        for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
            local specId, name, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
            print(classInfo.classFile, specIndex, specId, name)
        end
    end
end)

if not success then
    print("Error running original code:", error)
    
    -- Try alternative APIs for MoP
    print("=== Trying MoP Classic alternatives ===")
    
    -- Check what APIs we actually have
    print("GetNumClasses():", GetNumClasses and GetNumClasses() or "NOT AVAILABLE")
    print("GetSpecialization():", GetSpecialization and GetSpecialization() or "NOT AVAILABLE")
    print("GetSpecializationInfo():", GetSpecializationInfo and "EXISTS" or "NOT AVAILABLE")
    
    -- Try getting current player's spec info
    if GetSpecialization and GetSpecializationInfo then
        local currentSpec = GetSpecialization()
        if currentSpec then
            local specID, specName, description, icon, role = GetSpecializationInfo(currentSpec)
            print("Current spec:", currentSpec, specID, specName, role)
        else
            print("No current specialization detected")
        end
    end
    
    -- Check player class
    local className, classFile = UnitClass("player")
    print("Player class:", className, classFile)
end

print("=== Test complete ===")
